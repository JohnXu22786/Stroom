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
WEB_BUILD = Path("/tmp/stroom-anki-deck-error-web")
SCREENSHOT = ROOT / "docs/qa/anki_deck_load_error/anki-deck-load-error-320x640.png"
SCREENSHOT.parent.mkdir(parents=True, exist_ok=True)

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

try:
    base_url = f"http://127.0.0.1:{port}/"
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
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(base_url, wait_until="load", timeout=120_000)
        page.wait_for_timeout(7_000)
        page.screenshot(path=str(SCREENSHOT))

        image = Image.open(BytesIO(SCREENSHOT.read_bytes())).convert("RGB")
        if image.size != (320, 640):
            raise RuntimeError(f"Unexpected screenshot size: {image.size}")
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError("Flutter did not render the deck error screenshot")
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        print(
            {
                "screenshot": str(SCREENSHOT.relative_to(ROOT)),
                "viewport_css_px": {"width": 320, "height": 640},
                "device_pixel_ratio": 1,
                "locale": "en-US",
                "theme": "light",
                "text_scale": 1,
                "focus": "none",
                "keyboard": "closed (headless browser)",
                "fixture": "local StateError; no database, account data, or network calls",
            }
        )
        browser.close()
finally:
    server.terminate()
    server.wait(timeout=5)
