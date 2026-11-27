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
sys.path.insert(0, str(ROOT / "tool" / "qa"))
from capture_build_dependencies import needs_rebuild

STATE = Path("/workspace/.cloud-profile-state/vertical_backup_error_review")
TMP = Path("/workspace/.cloud-profile-state/vbe-tmp")
PUB_CACHE = STATE / "pub-cache"
WEB_BUILD = STATE / "web-build"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-backup-error"
SCREENSHOTS = [
    OUTPUT / "restore-error-de-DE-320x640-scale1-light.png",
    OUTPUT / "restore-error-details-de-DE-320x640-scale1-light.png",
]
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["PUB_CACHE"] = str(PUB_CACHE)
capture_entrypoint = ROOT / "tool/qa/vertical_backup_error_capture.dart"
if needs_rebuild(ROOT, capture_entrypoint, WEB_BUILD / "index.html"):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target=tool/qa/vertical_backup_error_capture.dart",
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
        page.wait_for_timeout(2_000)
        page.mouse.move(4, 4)
        page.screenshot(path=str(SCREENSHOTS[0]))
        page.mouse.move(160, 330)
        page.mouse.wheel(0, 5000)
        page.wait_for_timeout(300)
        page.mouse.move(4, 4)
        page.screenshot(path=str(SCREENSHOTS[1]))
        browser.close()

    for screenshot in SCREENSHOTS:
        image = Image.open(BytesIO(screenshot.read_bytes())).convert("RGB")
        if image.size != (320, 640):
            raise RuntimeError(f"Unexpected screenshot size: {image.size}")
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError("Flutter did not render the restore error fixture")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    print(
        {
            "screenshots": [str(path.relative_to(ROOT)) for path in SCREENSHOTS],
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "de-DE",
            "theme": "light Material 3",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "local fake restore diagnostic; no backup or restore was run",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
