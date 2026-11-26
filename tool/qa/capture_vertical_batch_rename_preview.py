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

from capture_build_dependencies import needs_rebuild


ROOT = Path(__file__).resolve().parents[2]
STATE = Path("/workspace/.cloud-profile-state/vertical-rename-preview")
TMP = STATE / "tmp"
PUB_CACHE = STATE / "pub-cache"
WEB_BUILD = STATE / "web-build"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-batch-rename-preview"
SCREENSHOTS = {
    "de-DE": OUTPUT / "batch-rename-preview-de-320x640-scale1-light.png",
    "en-US": OUTPUT / "batch-rename-preview-en-320x640-scale1_5-light.png",
}
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["PUB_CACHE"] = str(PUB_CACHE)
environment["FLUTTER_ROOT"] = "/workspace/sdks/flutter"
toolchain = "/workspace/toolchains/flutter-linux-deps/env"
environment["PATH"] = f"{toolchain}/bin:{environment['PATH']}"
environment["PKG_CONFIG_PATH"] = f"{toolchain}/lib/pkgconfig:{toolchain}/share/pkgconfig"
environment["PKG_CONFIG_LIBDIR"] = environment["PKG_CONFIG_PATH"]
environment["LD_LIBRARY_PATH"] = toolchain + "/lib"
environment["CC"] = toolchain + "/bin/clang"
environment["CXX"] = toolchain + "/bin/clang++"
capture_entrypoint = ROOT / "tool/qa/vertical_batch_rename_preview_capture.dart"
if needs_rebuild(ROOT, capture_entrypoint, WEB_BUILD / "index.html"):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--no-pub",
            "--release",
            "--target=tool/qa/vertical_batch_rename_preview_capture.dart",
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
        for locale, scale in [("de-DE", 1), ("en-US", 1.5)]:
            page = browser.new_page(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                reduced_motion="reduce",
            )
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{base_url}?locale={locale}&scale={scale}",
                wait_until="load",
                timeout=120_000,
            )
            page.wait_for_timeout(5_000)
            # The Flutter Web canvas does not expose individual Text widgets
            # to Playwright until semantics are explicitly activated. Tap the
            # known tab row at the measured 320 dp layouts instead.
            page.mouse.click(240, 200 if scale == 1 else 171)
            page.wait_for_timeout(500)
            page.mouse.move(180, 500)
            page.mouse.wheel(0, 720)
            page.wait_for_timeout(500)
            page.wait_for_timeout(500)
            page.screenshot(path=str(SCREENSHOTS[locale]))
            page.close()
        browser.close()

    for screenshot in SCREENSHOTS.values():
        image = Image.open(BytesIO(screenshot.read_bytes())).convert("RGB")
        if image.size != (320, 640):
            raise RuntimeError(f"Unexpected screenshot size: {image.size}")
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError("Flutter did not render the rename preview fixture")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    print(
        {
            "screenshots": [str(path.relative_to(ROOT)) for path in SCREENSHOTS.values()],
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locales": list(SCREENSHOTS),
            "text_scales": [1, 1.5],
            "theme": "light",
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "safe in-memory file and rename rule; no account data or network calls",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
