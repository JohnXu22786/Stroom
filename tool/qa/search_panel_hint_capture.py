from io import BytesIO
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
WEB_BUILD = ROOT / "build/search-panel-hint"
OUTPUT = ROOT / "docs/qa/search_panel_hint"
OUTPUT.mkdir(parents=True, exist_ok=True)
NARROW = OUTPUT / "search-panel-hint-de-320x640-scale2-light.png"
FITTING = OUTPUT / "search-panel-hint-en-390x844-scale1-light.png"
DARK_REDUCED = OUTPUT / "search-panel-hint-de-320x640-scale2-dark-reduced-motion.png"
PREVIEW = OUTPUT / "search-panel-hint-reveal-de-320x640-scale2-light.webm"

subprocess.run(
    [
        "flutter",
        "build",
        "web",
        "--no-pub",
        "--release",
        "--target",
        "tool/qa/search_panel_hint_capture.dart",
        "--output",
        str(WEB_BUILD),
    ],
    cwd=ROOT,
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


def open_search(
    page, base_url, *, locale, scale, theme="light", reduced=False, wait_ms=900
):
    page.goto(
        f"{base_url}?locale={locale}&scale={scale}&theme={theme}&reducedMotion={str(reduced).lower()}",
        wait_until="load",
        timeout=120_000,
    )
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
    page.wait_for_function("window.__searchPanelReady === true", timeout=120_000)
    page.mouse.click(page.viewport_size["width"] / 2, page.viewport_size["height"] / 2)
    page.wait_for_timeout(wait_ms)


def record_preview(page):
    with tempfile.TemporaryDirectory(
        prefix="search-panel-hint-frames-", dir=OUTPUT
    ) as frame_directory:
        frame_directory = Path(frame_directory)
        frame_rate = 10
        preview_duration = 14.9
        deadline = time.monotonic() + preview_duration
        next_frame = time.monotonic()
        frame_number = 0
        while time.monotonic() < deadline:
            (frame_directory / f"frame-{frame_number:04d}.png").write_bytes(
                page.screenshot()
            )
            frame_number += 1
            next_frame += 1 / frame_rate
            page.wait_for_timeout(max(0, round((next_frame - time.monotonic()) * 1000)))
        captured_frame_rate = frame_number / preview_duration
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-framerate",
                f"{captured_frame_rate:.5f}",
                "-i",
                str(frame_directory / "frame-%04d.png"),
                "-c:v",
                "libvpx-vp9",
                "-deadline",
                "good",
                "-cpu-used",
                "4",
                "-b:v",
                "0",
                "-crf",
                "28",
                str(PREVIEW),
            ],
            check=True,
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
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.add_init_script(
            """
            window.__searchPanelReady = false;
            window.addEventListener('search-panel-ready', () => {
              window.__searchPanelReady = true;
            }, { once: true });
            """
        )
        open_search(page, base_url, locale="de", scale=2)
        page.wait_for_timeout(250)
        NARROW.write_bytes(page.screenshot())

        preview_page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        preview_page.on("pageerror", lambda error: errors.append(str(error)))
        preview_page.add_init_script(
            """
            window.__searchPanelReady = false;
            window.addEventListener('search-panel-ready', () => {
              window.__searchPanelReady = true;
            }, { once: true });
            """
        )
        open_search(preview_page, base_url, locale="de", scale=2, wait_ms=300)
        record_preview(preview_page)
        preview_page.close()

        page.set_viewport_size({"width": 390, "height": 844})
        open_search(page, base_url, locale="en", scale=1)
        FITTING.write_bytes(page.screenshot())

        page.set_viewport_size({"width": 320, "height": 640})
        open_search(page, base_url, locale="de", scale=2, theme="dark", reduced=True)
        DARK_REDUCED.write_bytes(page.screenshot())
        browser.close()

    if errors:
        raise RuntimeError(f"Chromium reported page errors: {errors}")
    print(
        {
            "narrow": str(NARROW.relative_to(ROOT)),
            "fitting": str(FITTING.relative_to(ROOT)),
            "dark_reduced_motion": str(DARK_REDUCED.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "narrow_state": "German, 320x640, text scale 2, light theme",
            "fitting_state": "English, 390x844, text scale 1, light theme",
            "reduced_motion_state": "German, 320x640, text scale 2, dark theme, reduced motion",
            "preview_duration_seconds": 14.9,
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
