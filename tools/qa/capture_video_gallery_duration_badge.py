from io import BytesIO
from pathlib import Path
import subprocess
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/video-duration-badge"
FRAMES = OUTPUT / "frames"
PORT = 8896
URL = f"http://127.0.0.1:{PORT}/"
SERVER_LOG = OUTPUT / ".flutter-web.log"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) > 1:
            return
        page.wait_for_timeout(500)
    raise TimeoutError("Flutter Web did not render the production gallery fixture")


server_log = SERVER_LOG.open("w")
server = subprocess.Popen(
    [
        "flutter",
        "run",
        "--release",
        "--no-pub",
        "-d",
        "web-server",
        "--web-hostname",
        "127.0.0.1",
        "--web-port",
        str(PORT),
        "--target",
        "tools/qa/video_gallery_duration_badge_capture.dart",
    ],
    cwd=ROOT,
    stdout=server_log,
    stderr=subprocess.STDOUT,
)

try:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(
                "Flutter web server exited with "
                f"{server.returncode}: {SERVER_LOG.read_text()}"
            )
        try:
            with urlopen(URL, timeout=1):
                if "is being served at" in SERVER_LOG.read_text():
                    break
        except Exception:
            time.sleep(1)
    else:
        raise TimeoutError(
            f"Flutter web server did not become ready: {SERVER_LOG.read_text()}"
        )

    errors = []
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
            lambda message: errors.append(f"console {message.type}: {message.text}")
            if message.type == "error"
            else None,
        )

        cases = (
            ("fitting", "scale=1&hours=6", "1x"),
            ("clipped", "scale=3&hours=100", "3x"),
        )
        for state, params, scale_name in cases:
            for theme in ("light", "dark"):
                page.goto(
                    f"{URL}?{params}&theme={theme}",
                    wait_until="load",
                    timeout=120_000,
                )
                wait_for_rendered_flutter(page)
                page.wait_for_timeout(250)
                screenshot = page.screenshot()
                rendered = Image.open(BytesIO(screenshot)).convert("RGB")
                if rendered.size != (320, 640):
                    raise RuntimeError(f"Unexpected screenshot size: {rendered.size}")
                suffix = "100h" if state == "clipped" else "6h"
                filename = (
                    f"video-duration-{state}-{suffix}-320x640-{scale_name}-{theme}.png"
                )
                (OUTPUT / filename).write_bytes(screenshot)
                screenshots.append(filename)

        page.goto(
            f"{URL}?scale=3&hours=100&theme=light",
            wait_until="load",
            timeout=120_000,
        )
        wait_for_rendered_flutter(page)
        # Enable semantics for the browser accessibility tree; no control is focused.
        placeholder = page.locator("flt-semantics-placeholder")
        if placeholder.count():
            placeholder.evaluate("element => element.click()")
        duration_seconds = 11
        frames_per_second = 8
        frame_count = duration_seconds * frames_per_second
        frame_interval = 1 / frames_per_second
        start = time.monotonic()
        for index in range(frame_count):
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
            target = start + (index + 1) * frame_interval
            delay = target - time.monotonic()
            if delay > 0:
                time.sleep(delay)
        device_pixel_ratio = page.evaluate("devicePixelRatio")
        browser.close()

    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    if device_pixel_ratio != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    print(
        {
            "screenshots": screenshots,
            "preview": "video-duration-100h-reveal-320x640-scale3-light.webm",
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "en_US",
            "themes": ["light", "dark"],
            "screenshot_text_scales": {"fitting": 1, "clipped": 3},
            "fixture": "production VideoGalleryPage with one in-memory video record",
            "preview_duration_seconds": duration_seconds,
            "preview_frames": frame_count,
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
    server_log.close()
    SERVER_LOG.unlink(missing_ok=True)

subprocess.run(
    [
        "ffmpeg",
        "-y",
        "-framerate",
        "8",
        "-i",
        str(FRAMES / "frame-%03d.png"),
        "-c:v",
        "libvpx-vp9",
        "-pix_fmt",
        "yuv420p",
        "-b:v",
        "600k",
        str(OUTPUT / "video-duration-100h-reveal-320x640-scale3-light.webm"),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()
FRAMES.rmdir()
