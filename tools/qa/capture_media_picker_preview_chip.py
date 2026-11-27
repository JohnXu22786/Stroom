from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/media-picker-preview-chip"
PORT = 8901
BASE_URL = f"http://127.0.0.1:{PORT}/"
SERVER_LOG = Path("/tmp/media-picker-preview-chip-flutter.log")
OUTPUT.mkdir(parents=True, exist_ok=True)

server_log = SERVER_LOG.open("w")
server = subprocess.Popen(
    [
        "flutter",
        "run",
        "--no-pub",
        "-d",
        "web-server",
        "--web-hostname",
        "127.0.0.1",
        "--web-port",
        str(PORT),
        "--target",
        "tools/qa/media_picker_preview_chip_capture.dart",
    ],
    cwd=ROOT,
    stdout=server_log,
    stderr=subprocess.STDOUT,
)


def wait_for_server():
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(
                f"Flutter Web server exited with {server.returncode}: "
                f"{SERVER_LOG.read_text()[-3000:]}"
            )
        if "is being served at" in SERVER_LOG.read_text():
            return
        time.sleep(1)
    raise TimeoutError(
        f"Flutter Web server did not become ready: {SERVER_LOG.read_text()[-3000:]}"
    )


def open_selected_picker(browser, fixture, scale, static):
    page = browser.new_page(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    query = f"?fixture={fixture}&scale={scale}&static={int(static)}"
    page.goto(BASE_URL + query, wait_until="load", timeout=120_000)
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        image = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(image).stddev) >= 1:
            break
        page.wait_for_timeout(500)
    else:
        raise TimeoutError("Flutter Web remained blank after page load")
    if page.locator("flt-semantics-placeholder").count():
        page.locator("flt-semantics-placeholder").evaluate(
            "element => element.click()"
        )
    page.mouse.click(160, 320)
    page.wait_for_timeout(500)
    page.mouse.click(160, 95)
    page.mouse.move(300, 520)
    page.wait_for_timeout(150)
    if page.evaluate("devicePixelRatio") != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    return page, errors


try:
    wait_for_server()
    page_errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        captures = (
            ("fit", 1, "fitting-name-320x640-scale1-light.png"),
            ("three", 2, "three-line-name-320x640-scale2-light.png"),
            ("overflow", 2, "overflow-name-320x640-scale2-reduced-motion.png"),
        )
        for fixture, scale, filename in captures:
            page, errors = open_selected_picker(browser, fixture, scale, True)
            image = Image.open(BytesIO(page.screenshot())).convert("RGB")
            if image.size != (320, 640) or max(ImageStat.Stat(image).stddev) < 1:
                raise RuntimeError(f"Unexpected rendered capture: {image.size}")
            (OUTPUT / filename).write_bytes(page.screenshot())
            page_errors.extend(errors)
            page.close()

        preview, errors = open_selected_picker(browser, "overflow", 2, False)
        page_errors.extend(errors)
        fps = 8
        duration_seconds = 27
        frame_count = fps * duration_seconds
        with tempfile.TemporaryDirectory(prefix="media-picker-chip-frames-") as temp:
            frame_dir = Path(temp)
            start = time.monotonic()
            for index in range(frame_count):
                preview.screenshot(path=str(frame_dir / f"frame-{index:03d}.png"))
                delay = start + (index + 1) / fps - time.monotonic()
                if delay > 0:
                    time.sleep(delay)
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-framerate",
                    str(fps),
                    "-i",
                    str(frame_dir / "frame-%03d.png"),
                    "-c:v",
                    "libvpx-vp9",
                    "-pix_fmt",
                    "yuv420p",
                    "-b:v",
                    "500k",
                    str(OUTPUT / "overflow-name-reveal-preview.webm"),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        preview.close()
        browser.close()
    if page_errors:
        raise RuntimeError(f"Browser reported runtime errors: {page_errors}")
    print(
        {
            "output": str(OUTPUT.relative_to(ROOT)),
            "captures": [filename for _, _, filename in captures],
            "preview": "overflow-name-reveal-preview.webm",
            "preview_frames": frame_count,
            "preview_fps": fps,
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "theme": "light Material 3",
            "network": "none; local in-memory media fixture",
            "page_errors": page_errors,
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
