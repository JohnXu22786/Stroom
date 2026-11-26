from io import BytesIO
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
WEB_BUILD = ROOT / "build/anki-card-browser-search-hint"
OUTPUT = ROOT / "docs/qa/anki_card_browser_search_hint"
NARROW = OUTPUT / "anki-search-hint-fr-320x640-scale1_8-light.png"
FITTING = OUTPUT / "anki-search-hint-en-390x844-scale1-light.png"
PREVIEW = OUTPUT / "anki-search-hint-reveal-fr-320x640-scale1_8-light.webm"
OUTPUT.mkdir(parents=True, exist_ok=True)

subprocess.run(
    [
        "flutter",
        "build",
        "web",
        "--no-pub",
        "--release",
        "--target",
        "tool/qa/anki_card_browser_search_hint_capture.dart",
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


def record_reveal_preview(page):
    with tempfile.TemporaryDirectory(
        prefix="anki-search-hint-frames-", dir=OUTPUT
    ) as frame_directory:
        frame_directory = Path(frame_directory)
        frame_rate = 10
        preview_duration = 9
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
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-framerate",
                str(frame_rate),
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
        page.goto(f"{base_url}?locale=fr&scale=1.8&theme=light", wait_until="load", timeout=120_000)
        page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
        page.wait_for_timeout(1_500)
        page.mouse.click(160, 84)
        page.wait_for_timeout(1_500)
        screenshot = page.screenshot()
        if Image.open(BytesIO(screenshot)).size != (320, 640):
            raise RuntimeError("Unexpected French screenshot dimensions")
        NARROW.write_bytes(screenshot)

        preview_page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        preview_page.on("pageerror", lambda error: errors.append(str(error)))
        preview_page.add_init_script(
            """
            window.__ankiCardBrowserRendered = false;
            window.addEventListener('anki-card-browser-rendered', () => {
              window.__ankiCardBrowserRendered = true;
            }, { once: true });
            """
        )
        preview_page.goto(
            f"{base_url}?locale=fr&scale=1.8&theme=light",
            wait_until="load",
            timeout=120_000,
        )
        preview_page.locator("flt-semantics-placeholder").wait_for(
            timeout=120_000
        )
        preview_page.wait_for_function(
            "window.__ankiCardBrowserRendered === true", timeout=120_000
        )
        preview_page.mouse.click(160, 84)
        preview_active_element = preview_page.evaluate(
            "document.activeElement?.tagName?.toLowerCase()"
        )
        record_reveal_preview(preview_page)
        preview_page.close()

        page.set_viewport_size({"width": 390, "height": 844})
        page.goto(f"{base_url}?locale=en&scale=1&theme=light", wait_until="load", timeout=120_000)
        page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
        page.wait_for_timeout(1_500)
        page.mouse.click(195, 84)
        page.wait_for_timeout(250)
        fit_screenshot = page.screenshot()
        if Image.open(BytesIO(fit_screenshot)).size != (390, 844):
            raise RuntimeError("Unexpected English screenshot dimensions")
        if max(ImageStat.Stat(Image.open(BytesIO(fit_screenshot)).convert("RGB")).stddev) < 1:
            raise RuntimeError("Flutter Web produced a blank English screenshot")
        FITTING.write_bytes(fit_screenshot)
        browser.close()

    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    print(
        {
            "narrow": str(NARROW.relative_to(ROOT)),
            "fitting": str(FITTING.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "narrow_state": "empty search field, focused, French, 320x640, text scale 1.8, light theme, LTR",
            "fitting_state": "empty search field, focused, English, 390x844, text scale 1, light theme, LTR",
            "preview_active_element": preview_active_element,
            "preview_start": "immediately after first Flutter frame and search-field focus",
            "device_pixel_ratio": 1,
            "page_errors": errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
