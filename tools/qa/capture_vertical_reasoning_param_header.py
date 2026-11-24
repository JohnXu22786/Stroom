from io import BytesIO
from pathlib import Path
import os
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
STATE = Path(
    "/workspace/.cloud-profile-state/stroom-guideline-confirmed/round25/vertical_reasoning_param_header"
)
OUTPUT = ROOT / "docs/qa/vertical_reasoning_param_header"
WEB_BUILD = STATE / "web-build"
SCREENSHOT = OUTPUT / "reasoning-param-header-fr-320x640-1x-light.png"
TMP = Path("/workspace/.cloud-profile-state/vrh-tmp")
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["XDG_CACHE_HOME"] = str(STATE / "xdg-cache")
environment["PUB_CACHE"] = str(STATE / "pub-cache")
toolchain = Path("/workspace/toolchains/flutter-linux-deps/env")
environment["PKG_CONFIG_PATH"] = ":".join(
    [str(toolchain / "lib/pkgconfig"), str(toolchain / "share/pkgconfig")]
)
environment["PKG_CONFIG_LIBDIR"] = environment["PKG_CONFIG_PATH"]
environment["CC"] = str(toolchain / "bin/clang")
environment["CXX"] = str(toolchain / "bin/clang++")
environment["LD_LIBRARY_PATH"] = str(toolchain / "lib")
environment["PATH"] = f"{toolchain / 'bin'}:{environment['PATH']}"

entrypoint = ROOT / "tools/qa/vertical_reasoning_param_header_capture.dart"
capture_sources = [
    entrypoint,
    ROOT / "lib/pages/llm_model_config_page_reasoning_builders.dart",
]
if not (WEB_BUILD / "index.html").exists() or any(
    source.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
    for source in capture_sources
):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            f"--target={entrypoint}",
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
        page.mouse.move(160, 500)
        page.mouse.wheel(0, 5000)
        page.wait_for_timeout(250)
        page.mouse.wheel(0, -1300)
        page.wait_for_timeout(500)
        page.mouse.move(4, 4)
        screenshot = page.screenshot()
        browser.close()

    image = Image.open(BytesIO(screenshot)).convert("RGB")
    if image.size != (320, 640):
        raise RuntimeError(f"Unexpected screenshot size: {image.size}")
    if max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError("Flutter did not render the production page")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    SCREENSHOT.write_bytes(screenshot)
    print(
        {
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr-FR",
            "theme": "light Material 3 blue-seeded",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "in-memory unsaved model and provider; no persistence or provider request",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
