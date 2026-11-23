from io import BytesIO
from pathlib import Path
import os
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
STATE = Path("/workspace/.cloud-profile-state/vertical-anki-delete-confirm")
TMP = STATE / "tmp"
PUB_CACHE = STATE / "pub-cache"
WEB_BUILD = STATE / "web-build"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-anki-delete-confirm"
SCREENSHOTS = {
    1: OUTPUT / "anki-delete-confirm-en-320x640-scale1-light.png",
    2: OUTPUT / "anki-delete-confirm-en-320x640-scale2-light.png",
}
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["PUB_CACHE"] = str(PUB_CACHE)
capture_entrypoint = ROOT / "tool/qa/anki_delete_confirmation_capture.dart"
if (
    not (WEB_BUILD / "index.html").exists()
    or capture_entrypoint.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--no-pub",
            "--release",
            "--target=tool/qa/anki_delete_confirmation_capture.dart",
            f"--output={WEB_BUILD}",
        ],
        cwd=ROOT,
        env=environment,
        check=True,
    )

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
            reduced_motion="reduce",
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        for scale, screenshot in SCREENSHOTS.items():
            page.goto(f"{base_url}?scale={scale}", wait_until="load", timeout=120_000)
            page.wait_for_timeout(5_000)
            page.screenshot(path=str(STATE / f"anki-delete-initial-scale{scale}.png"))
            menu_y = 165 if scale == 1 else 383
            page.mouse.click(272, menu_y)
            page.wait_for_timeout(500)
            page.screenshot(path=str(STATE / f"anki-delete-menu-scale{scale}.png"))
            page.mouse.click(220 if scale == 1 else 176, menu_y + 122)
            page.wait_for_timeout(500)
            page.screenshot(path=str(screenshot))
        browser.close()

    for screenshot in SCREENSHOTS.values():
        image = Image.open(BytesIO(screenshot.read_bytes())).convert("RGB")
        if image.size != (320, 640):
            raise RuntimeError(f"Unexpected screenshot size: {image.size}")
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError("Flutter did not render the delete fixture")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    print(
        {
            "screenshots": [str(path.relative_to(ROOT)) for path in SCREENSHOTS.values()],
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "en-US",
            "theme": "light",
            "text_scales": [1, 2],
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "long safe in-memory deck name; no account data or network calls",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
