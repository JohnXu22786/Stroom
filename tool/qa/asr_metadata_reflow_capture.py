from io import BytesIO
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
WEB_BUILD = Path("/tmp/stroom-asr-metadata-web")
CAPTURE = ROOT / "docs/qa/asr_metadata_reflow/asr-metadata-reflow-es-320x640-1x-light.png"
CAPTURE.parent.mkdir(parents=True, exist_ok=True)

with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    port = listener.getsockname()[1]

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
errors = []

try:
    base_url = f"http://127.0.0.1:{port}/?locale=es-ES&theme=light&scale=1"
    for _ in range(100):
        if server.poll() is not None:
            raise RuntimeError("Local Flutter Web server exited before becoming ready")
        try:
            with urlopen(base_url, timeout=1):
                break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError("Local Flutter Web server did not become ready")

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(base_url, wait_until="load", timeout=120_000)
        page.wait_for_timeout(8_000)

        # Open the real ASR page's audio-source sheet, then its in-app picker.
        page.mouse.click(78, 168)
        page.wait_for_timeout(700)
        page.mouse.click(150, 470)
        page.wait_for_timeout(500)

        screenshot = page.screenshot()
        image = Image.open(BytesIO(screenshot)).convert("RGB")
        if page.viewport_size != {"width": 320, "height": 640}:
            raise RuntimeError(f"Unexpected viewport: {page.viewport_size}")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Chromium devicePixelRatio is not 1")
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError("Flutter did not render the picker screenshot")
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")

        CAPTURE.write_bytes(screenshot)
        print(
            {
                "output": str(CAPTURE.relative_to(ROOT)),
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "es-ES",
                "theme": "light",
                "text_scale": 1,
                "focus": "none",
                "keyboard": "closed",
                "fixture": "one in-memory AudioRecord; no audio bytes or provider/network requests",
                "page_errors": errors,
            }
        )
        browser.close()
finally:
    server.terminate()
    server.wait(timeout=5)

