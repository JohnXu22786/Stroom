from pathlib import Path
import struct
import subprocess
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-floating-capture-button"
SCREENSHOT = OUTPUT / "capture-button-zh-CN-320x640-scale1-light.png"
PREVIEW = OUTPUT / "capture-button-zh-CN-320x640-scale3-light.webm"
FRAMES = OUTPUT / "frames"
PORT = 8898
URL = f"http://127.0.0.1:{PORT}/"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)
SERVER_LOG = OUTPUT / ".flutter-web.log"


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        screenshot = page.screenshot()
        if len(screenshot) > 5_000:
            return
        page.wait_for_timeout(1_000)
    raise TimeoutError("Flutter Web did not render the capture panel")


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
        "tools/qa/vertical_floating_capture_button_capture.dart",
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
        time.sleep(1)
    else:
        raise TimeoutError(
            f"Flutter web server did not become ready: {SERVER_LOG.read_text()}"
        )

    errors = []
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

        page.goto(f"{URL}?scale=1", wait_until="load", timeout=120_000)
        wait_for_rendered_flutter(page)
        page.mouse.click(100, 64)
        page.wait_for_timeout(250)
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        screenshot = page.screenshot()
        if not screenshot.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Chromium did not return a PNG screenshot")
        if struct.unpack(">II", screenshot[16:24]) != (320, 640):
            raise RuntimeError("Capture screenshot dimensions are not 320x640")
        if len(screenshot) < 1_000:
            raise RuntimeError("Flutter Web screenshot appears blank")
        SCREENSHOT.write_bytes(screenshot)

        page.goto(f"{URL}?scale=3", wait_until="load", timeout=120_000)
        wait_for_rendered_flutter(page)
        page.mouse.click(100, 100)
        page.wait_for_timeout(250)
        duration_seconds = 10
        frames_per_second = 6
        frame_count = duration_seconds * frames_per_second
        frame_interval = 1 / frames_per_second
        start = time.monotonic()
        for index in range(frame_count):
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
            target = start + (index + 1) * frame_interval
            delay = target - time.monotonic()
            if delay > 0:
                time.sleep(delay)

        print(
            {
                "screenshot": str(SCREENSHOT.relative_to(ROOT)),
                "preview": str(PREVIEW.relative_to(ROOT)),
                "viewport_css_px": {"width": 320, "height": 640},
                "device_pixel_ratio": 1,
                "locale": "zh_CN",
                "theme": "light Material 3",
                "screenshot_text_scale": 1,
                "preview_text_scale": 3,
                "focus": "selected demo video row; no text input focused",
                "keyboard": "closed (browser fixture)",
                "fixture": "local synthetic URL; no media or network request",
                "preview_frames": frame_count,
                "page_errors": errors,
            }
        )
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
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
        "6",
        "-i",
        str(FRAMES / "frame-%03d.png"),
        "-c:v",
        "libvpx-vp9",
        "-pix_fmt",
        "yuv420p",
        "-b:v",
        "500k",
        str(PREVIEW),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()
FRAMES.rmdir()
