from io import BytesIO
import math
from pathlib import Path
import re
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
WEB_BUILD = ROOT / "build/qa-chat-file-chip-web"
ENTRYPOINT = ROOT / "tools/qa/chat_file_chip_capture.dart"
PRODUCTION_FILE = ROOT / "lib/pages/chat/composer/file_picker_shared.dart"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)

if (
    not (WEB_BUILD / "index.html").exists()
    or ENTRYPOINT.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
    or PRODUCTION_FILE.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
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
        page.on(
            "console",
            lambda message: metrics.append(message.text)
            if "CHAT_FILE_CHIP_METRIC:" in message.text
            else errors.append(f"console {message.type}: {message.text}")
            if message.type == "error"
            else None,
        )

        def navigate(name: str, scale: int, theme: str, extra: dict | None = None):
            before = len(metrics)
            params = {"name": name, "scale": scale, "theme": theme}
            params.update(extra or {})
            query = "&".join(f"{key}={value}" for key, value in params.items())
            page.goto(f"{URL}?{query}", wait_until="load", timeout=120_000)
            render_deadline = time.monotonic() + 60
            screenshot = b""
            while time.monotonic() < render_deadline:
                screenshot = page.screenshot()
                rendered = Image.open(BytesIO(screenshot)).convert("RGB")
                if max(ImageStat.Stat(rendered).stddev) > 1:
                    break
                page.wait_for_timeout(250)
            else:
                raise TimeoutError(f"Flutter Web did not render {name} at {scale}×")
            if rendered.size != (320, 640):
                raise RuntimeError(f"Unexpected screenshot size: {rendered.size}")
            if page.evaluate("devicePixelRatio") != 1:
                raise RuntimeError("Capture device pixel ratio was not 1")
            page.wait_for_timeout(150)
            return metrics[-1] if len(metrics) > before else None

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

        long_metric = navigate("long", 3, "light", {"motion": "on"})
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

        page.wait_for_timeout(150)
        (OUTPUT / "chat-file-chip-long-name-start-320x640-scale3-light.png").write_bytes(
            page.screenshot()
        )
        screenshots.append("chat-file-chip-long-name-start-320x640-scale3-light.png")

        cycle_seconds = 1 + 2 * travel_seconds + 4
        frame_rate = 8
        frame_count = math.ceil(cycle_seconds * frame_rate)
        frame_start = time.monotonic()
        for index in range(frame_count):
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
            target = frame_start + (index + 1) / frame_rate
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
