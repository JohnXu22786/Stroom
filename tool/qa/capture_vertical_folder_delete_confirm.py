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
STATE = Path("/workspace/.cloud-profile-state/vertical_folder_delete_confirm")
TMP = STATE / "tmp"
PUB_CACHE = STATE / "pub-cache"
WEB_BUILD = STATE / "web-build"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-folder-delete-confirm"
SCREENSHOT = OUTPUT / "folder-delete-confirm-en-320x640-1x-light.png"
SCROLLED_SCREENSHOT = (
    OUTPUT / "folder-delete-confirm-en-320x640-1x-light-scrolled.png"
)
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["PUB_CACHE"] = str(PUB_CACHE)
capture_entrypoint = ROOT / "tool/qa/vertical_folder_delete_confirm_capture.dart"
if (
    not (WEB_BUILD / "index.html").exists()
    or capture_entrypoint.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target=tool/qa/vertical_folder_delete_confirm_capture.dart",
            f"--output={WEB_BUILD}",
            "--no-wasm-dry-run",
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
        page.goto(base_url, wait_until="load", timeout=120_000)
        page.wait_for_timeout(5_000)
        # Enter the first of 40 nested local fixture folders, then follow each
        # visible child row. The target's menu and confirmation are production UI.
        page.mouse.click(150, 91)
        page.wait_for_timeout(500)
        for _ in range(38):
            page.mouse.click(150, 145)
            page.wait_for_timeout(500)
        page.mouse.click(280, 145)
        page.wait_for_timeout(500)
        page.mouse.click(198, 462)
        page.wait_for_timeout(1_000)
        page.screenshot(path=str(SCREENSHOT))
        page.mouse.move(150, 350)
        page.mouse.wheel(0, 900)
        page.wait_for_timeout(500)
        page.screenshot(path=str(SCROLLED_SCREENSHOT))
        browser.close()

    image = Image.open(BytesIO(SCREENSHOT.read_bytes())).convert("RGB")
    if image.size != (320, 640):
        raise RuntimeError(f"Unexpected screenshot size: {image.size}")
    if len(image.getcolors(320 * 640) or []) <= 10:
        raise RuntimeError("Flutter did not render the delete confirmation fixture")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    scrolled_image = Image.open(BytesIO(SCROLLED_SCREENSHOT.read_bytes()))
    if scrolled_image.size != (320, 640):
        raise RuntimeError(f"Unexpected scrolled screenshot size: {scrolled_image.size}")
    print(
        {
            "screenshots": [
                str(SCREENSHOT.relative_to(ROOT)),
                str(SCROLLED_SCREENSHOT.relative_to(ROOT)),
            ],
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "en-US",
            "theme": "light",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "40 nested local folder names; delete callback is a no-op",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
