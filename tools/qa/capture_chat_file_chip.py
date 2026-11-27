from io import BytesIO
import math
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/chat-file-chip"
FRAMES = OUTPUT / "frames"
WEB_BUILD = ROOT / "build/qa-chat-file-chip-web-r10-01"
ENTRYPOINT = ROOT / "tools/qa/chat_file_chip_capture.dart"
PRODUCTION_FILE = ROOT / "lib/pages/chat/composer/file_picker_shared.dart"
PRODUCTION_DIALOG = ROOT / "lib/pages/chat/composer/chat_file_picker_dialog.dart"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()

if (
    not (WEB_BUILD / "index.html").exists()
    or ENTRYPOINT.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
    or PRODUCTION_FILE.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
    or PRODUCTION_DIALOG.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
):
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            f"--target={ENTRYPOINT}",
            f"--output={WEB_BUILD}",
            "--no-wasm-dry-run",
        ],
        cwd=ROOT,
        check=True,
    )

# Flutter's custom `--output` build omits web root files referenced by the
# generated index. Copy the tracked static web assets without replacing the
# generated index or Flutter bootstrap so a clean QA build is self-contained.
for source in (ROOT / "web").rglob("*"):
    if source.is_file() and source.name != "index.html":
        destination = WEB_BUILD / source.relative_to(ROOT / "web")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    port = listener.getsockname()[1]
URL = f"http://127.0.0.1:{port}/"
server = subprocess.Popen(
    [
        sys.executable,
        "-m",
        "http.server",
        str(port),
        "--bind",
        "127.0.0.1",
        "--directory",
        str(WEB_BUILD),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(f"Static Flutter web server exited with {server.returncode}")
        try:
            with urlopen(URL, timeout=1):
                break
        except Exception:
            time.sleep(1)
    else:
        raise TimeoutError("Static Flutter web server did not become ready")

    errors = []
    metrics = []
    metric_times = {}
    screenshots = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        def record_console(message):
            if "CHAT_FILE_CHIP_METRIC:" in message.text:
                metrics.append(message.text)
                if message.text.startswith("CHAT_FILE_CHIP_METRIC:long "):
                    # The metric is emitted during the long-name widget's first
                    # build, just before layout starts the one-second timer.
                    metric_times["long"] = time.monotonic()
            elif message.type == "error":
                errors.append(
                    f"console {message.type}: {message.text} ({message.location.get('url')})"
                )

        page.on("console", record_console)

        def navigate(
            name: str,
            scale: int,
            theme: str,
            extra: dict | None = None,
            *,
            capture_first_frame: bool = False,
        ):
            before = len(metrics)
            params = {"name": name, "scale": scale, "theme": theme}
            params.update(extra or {})
            query = "&".join(f"{key}={value}" for key, value in params.items())
            # For the motion route wait only for navigation commit. Waiting
            # for all Flutter web startup work can consume its one-second
            # initial pause before the first rendered frame is captured.
            page.goto(
                f"{URL}?{query}",
                wait_until="domcontentloaded" if capture_first_frame else "load",
                timeout=120_000,
            )
            render_deadline = time.monotonic() + 60
            screenshot = b""
            while time.monotonic() < render_deadline:
                screenshot = page.screenshot()
                rendered = Image.open(BytesIO(screenshot)).convert("RGB")
                if (
                    max(ImageStat.Stat(rendered).stddev) > 1
                    and len(metrics) > before
                ):
                    break
                page.wait_for_timeout(50)
            else:
                raise TimeoutError(f"Flutter Web did not render {name} at {scale}×")
            first_frame_time = time.monotonic()
            if rendered.size != (320, 640):
                raise RuntimeError(f"Unexpected screenshot size: {rendered.size}")
            if page.evaluate("devicePixelRatio") != 1:
                raise RuntimeError("Capture device pixel ratio was not 1")
            if not capture_first_frame:
                page.wait_for_timeout(150)
            if capture_first_frame:
                metric = metrics[-1] if len(metrics) > before else None
                return metric, screenshot, first_frame_time
            return metrics[-1] if len(metrics) > before else None

        def capture_picker(scale: int):
            params = {
                "route": "picker",
                "file": "annual.pdf",
                "scale": scale,
                "theme": "light",
            }
            query = "&".join(f"{key}={value}" for key, value in params.items())
            page.goto(f"{URL}?{query}", wait_until="load", timeout=120_000)
            page.wait_for_timeout(2_500)
            # The fixture's only record is the first text row. Click the file
            # row directly so the production dialog loads the file and
            # shows the real chip at both text scales.
            checkbox_y = 140 if scale == 1 else 165
            page.mouse.click(140, checkbox_y)
            screenshot = page.screenshot()
            checkbox_color = (0, 0, 0)
            selection_deadline = time.monotonic() + 5
            while time.monotonic() < selection_deadline:
                image = Image.open(BytesIO(screenshot)).convert("RGB")
                if image.size != (320, 640):
                    raise RuntimeError("Unexpected production dialog screenshot size")
                checkbox_color = image.getpixel((30, checkbox_y))
                if checkbox_color[2] - checkbox_color[0] >= 40:
                    break
                page.wait_for_timeout(100)
                screenshot = page.screenshot()
            else:
                raise RuntimeError(
                    f"Production route did not select annual.pdf at scale {scale}×; "
                    f"checkbox pixel was {checkbox_color}"
                )
            return screenshot

        picker_fit = capture_picker(1)
        (OUTPUT / "chat-file-picker-dialog-annual-320x640-scale1-light.png").write_bytes(
            picker_fit
        )
        screenshots.append("chat-file-picker-dialog-annual-320x640-scale1-light.png")

        picker_scaled = capture_picker(3)
        (OUTPUT / "chat-file-picker-dialog-annual-320x640-scale3-light.png").write_bytes(
            picker_scaled
        )
        screenshots.append("chat-file-picker-dialog-annual-320x640-scale3-light.png")

        navigate("fit", 1, "light")
        (OUTPUT / "chat-file-chip-fitting-320x640-scale1-light.png").write_bytes(
            page.screenshot()
        )
        screenshots.append("chat-file-chip-fitting-320x640-scale1-light.png")

        navigate("fit", 1, "dark")
        (OUTPUT / "chat-file-chip-fitting-320x640-scale1-dark.png").write_bytes(
            page.screenshot()
        )
        screenshots.append("chat-file-chip-fitting-320x640-scale1-dark.png")

        two_line_metric = navigate("two-line", 3, "light")
        if two_line_metric is not None:
            two_line = re.search(
                r"lines=(\d+) height=([\d.]+) twoLineHeight=([\d.]+) exceedsTwo=(true|false)",
                two_line_metric,
            )
            if not two_line:
                raise RuntimeError(f"Could not parse two-line layout measurement: {two_line_metric}")
            line_count, natural_height, _, exceeds_two = two_line.groups()
            if line_count != "2" or float(natural_height) <= 56 or exceeds_two != "false":
                raise RuntimeError(
                    "The selected file does not reproduce an exact two-line parent clip: "
                    f"{two_line_metric}"
                )
        else:
            two_line_metric = "Console diagnostic unavailable; see README measurement."
        (OUTPUT / "chat-file-chip-two-line-320x640-scale3-light.png").write_bytes(
            page.screenshot()
        )
        screenshots.append("chat-file-chip-two-line-320x640-scale3-light.png")

        long_metric, start_frame, first_frame_time = navigate(
            "long", 3, "light", {"motion": "on"}, capture_first_frame=True
        )
        if "long" not in metric_times:
            raise RuntimeError(
                "Missing the first long-name layout timestamp; "
                "cannot preserve the initial motion pause"
            )
        long_layout = re.search(
            r"lines=(\d+) height=([\d.]+) twoLineHeight=([\d.]+) exceedsTwo=(true|false)",
            long_metric or "",
        )
        if long_layout:
            long_lines, full_height, two_line_height, exceeds_two = long_layout.groups()
            if int(long_lines) <= 2 or exceeds_two != "true":
                raise RuntimeError(f"Long filename did not exceed the two-line limit: {long_metric}")
            travel_seconds = (float(full_height) - float(two_line_height)) / 24
        else:
            long_metric = "Console diagnostic unavailable; using the verified 22.92 s cycle."
            travel_seconds = 8.96

        (OUTPUT / "chat-file-chip-long-name-start-320x640-scale3-light.png").write_bytes(
            start_frame
        )
        screenshots.append("chat-file-chip-long-name-start-320x640-scale3-light.png")

        cycle_seconds = 1 + 2 * travel_seconds + 4
        frame_rate = 8
        # `navigate` waits for the first nonblank render and a settle frame, so
        # the widget's initial timer has already elapsed when frame capture
        # begins. Repeat the first rendered still for that elapsed interval to
        # preserve the complete one-second on-screen pause in the video. Fail
        # rather than emit an invalid preview if capture starts after motion.
        elapsed_before_capture = max(
            0,
            first_frame_time - metric_times.get("long", first_frame_time),
        )
        if elapsed_before_capture >= 1:
            raise RuntimeError(
                "Motion capture started after the long-name initial pause"
            )
        initial_hold_frames = math.ceil(
            max(elapsed_before_capture, 1 - elapsed_before_capture) * frame_rate
        )
        # The rounded-up still frames can add up to (1/fps) more time than
        # the measured delay. Include that excess in the recorded cycle so
        # the final endpoint still receives its full two-second pause.
        initial_hold_seconds = initial_hold_frames / frame_rate
        frame_count = math.ceil(
            (cycle_seconds + initial_hold_seconds - elapsed_before_capture)
            * frame_rate
        )
        for index in range(initial_hold_frames):
            (FRAMES / f"frame-{index:03d}.png").write_bytes(start_frame)

        frame_start = time.monotonic()
        for index in range(initial_hold_frames, frame_count):
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
            target = frame_start + (index - initial_hold_frames + 1) / frame_rate
            delay = target - time.monotonic()
            if delay > 0:
                page.wait_for_timeout(round(delay * 1000))
        return_path = OUTPUT / "chat-file-chip-long-name-return-320x640-scale3-light.png"
        page.screenshot(path=str(return_path))
        screenshots.append(return_path.name)
        browser.close()

    if errors:
        raise RuntimeError(f"Browser reported errors: {errors}")

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-framerate",
            str(frame_rate),
            "-i",
            str(FRAMES / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-pix_fmt",
            "yuv420p",
            "-b:v",
            "500k",
            str(OUTPUT / "chat-file-chip-vertical-reveal.webm"),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    for frame in FRAMES.glob("frame-*.png"):
        frame.unlink()
    FRAMES.rmdir()
    print(
        {
            "screenshots": screenshots,
            "motion_preview": "chat-file-chip-vertical-reveal.webm",
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "en-US",
            "theme": "light and dark Material 3 fitting states; light enlarged states",
            "text_scales": [1, 3],
            "two_line_metric": two_line_metric,
            "long_name_metric": long_metric,
            "motion": "start, vertical endpoint pause, return, and second endpoint pause",
            "motion_preview_seconds": round(frame_count / frame_rate, 2),
            "motion_elapsed_before_capture_seconds": round(
                elapsed_before_capture, 3
            ),
            "motion_initial_hold_seconds": round(
                initial_hold_frames / frame_rate, 3
            ),
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
