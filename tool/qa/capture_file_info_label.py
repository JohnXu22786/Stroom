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
STATE = Path(
    "/workspace/.cloud-profile-state/stroom-guideline-confirmed/round14/vertical_file_info_label"
)
TMP = STATE / "tmp"
PUB_CACHE = STATE / "pub-cache"
WEB_BUILD = STATE / "web-build"
FRAMES = STATE / "frames"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-file-info-label"
SCREENSHOT = OUTPUT / "file-info-dialog-fr-320x640-scale1-light.png"
RESPONSIVE_SCREENSHOT = OUTPUT / "file-info-close-de-320x640-scale1-light.png"
PREVIEW = OUTPUT / "file-info-label-reveal-fr-320x640.webm"
for directory in (TMP, FRAMES, OUTPUT):
    directory.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment["TMPDIR"] = str(TMP)
environment["PUB_CACHE"] = str(PUB_CACHE)
toolchain = Path("/workspace/toolchains/flutter-linux-deps/env")
environment["PKG_CONFIG_PATH"] = f"{toolchain}/lib/pkgconfig:{toolchain}/share/pkgconfig"
environment["PKG_CONFIG_LIBDIR"] = environment["PKG_CONFIG_PATH"]
environment["CC"] = str(toolchain / "bin/clang")
environment["CXX"] = str(toolchain / "bin/clang++")
environment["LD_LIBRARY_PATH"] = f"{toolchain}/lib"
environment["PATH"] = f"{toolchain}/bin:{environment['PATH']}"
capture_entrypoint = ROOT / "tool/qa/file_info_label_capture.dart"
if (
    not (WEB_BUILD / "index.html").exists()
    or capture_entrypoint.stat().st_mtime > (WEB_BUILD / "index.html").stat().st_mtime
    or (ROOT / "lib/pages/chat/dialogs/file_info_dialog.dart").stat().st_mtime
    > (WEB_BUILD / "index.html").stat().st_mtime
    or (ROOT / "lib/pages/chat/widgets/info_row.dart").stat().st_mtime
    > (WEB_BUILD / "index.html").stat().st_mtime
):
    subprocess.run(
        [
            "/workspace/sdks/flutter/bin/flutter",
            "build",
            "web",
            "--no-pub",
            "--release",
            "--target=tool/qa/file_info_label_capture.dart",
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
            raise RuntimeError("Flutter Web server exited before becoming ready")
        try:
            with urlopen(base_url, timeout=1):
                break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError("Flutter Web server did not become ready")

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
        page.goto(f"{base_url}?locale=fr-FR&scale=1&theme=light", wait_until="load", timeout=120_000)
        page.wait_for_timeout(4_000)
        page.mouse.click(160, 320)
        page.wait_for_timeout(250)
        page.screenshot(path=str(SCREENSHOT))

        responsive_page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        responsive_page.on("pageerror", lambda error: errors.append(str(error)))
        responsive_page.goto(
            f"{base_url}?locale=de-DE&scale=1&theme=light",
            wait_until="load",
            timeout=120_000,
        )
        responsive_page.wait_for_timeout(4_000)
        responsive_page.mouse.click(160, 320)
        responsive_page.wait_for_timeout(250)
        responsive_page.screenshot(path=str(RESPONSIVE_SCREENSHOT))
        responsive_page.close()

        for frame in FRAMES.glob("frame-*.png"):
            frame.unlink()
        for index in range(40):
            page.wait_for_timeout(250)
            page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
        browser.close()

    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    image = Image.open(BytesIO(SCREENSHOT.read_bytes())).convert("RGB")
    if image.size != (320, 640):
        raise RuntimeError(f"Unexpected screenshot size: {image.size}")
    responsive_image = Image.open(BytesIO(RESPONSIVE_SCREENSHOT.read_bytes())).convert(
        "RGB"
    )
    if responsive_image.size != (320, 640):
        raise RuntimeError(f"Unexpected responsive screenshot size: {responsive_image.size}")
    if len(image.getcolors(320 * 640) or []) <= 10:
        raise RuntimeError("Flutter did not render the file info dialog")
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-framerate",
            "4",
            "-i",
            str(FRAMES / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-b:v",
            "1M",
            "-pix_fmt",
            "yuv420p",
            str(PREVIEW),
        ],
        check=True,
    )
    print(
        {
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "responsive_close_screenshot": str(RESPONSIVE_SCREENSHOT.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr-FR",
            "theme": "light",
            "text_scale": 1,
            "focus": "none",
            "keyboard": "closed (headless browser)",
            "fixture": "in-memory local document; no account data or network request",
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
