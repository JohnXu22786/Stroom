from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/catcatch-resource-badge"
WEB_BUILD = Path(
    "/workspace/.cloud-profile-state/vertical_catcatch_resource_badge/web-build"
)
URL = "http://127.0.0.1:8879"
OUTPUT.mkdir(parents=True, exist_ok=True)

server = subprocess.Popen(
    ["python3", "-m", "http.server", "8879", "--directory", str(WEB_BUILD)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
time.sleep(1)
if server.poll() is not None:
    raise RuntimeError("Could not start local screenshot fixture server")
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        context = browser.new_context(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="reduce",
        )
        page = context.new_page()
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(f"{URL}/?motion=false&scale=1", wait_until="load")
        page.wait_for_timeout(12_000)
        page.mouse.move(160, 400)
        page.mouse.wheel(0, 32)
        page.wait_for_timeout(500)
        screenshot = OUTPUT / "resource-kind-badges-fr-320x640-scale1-light.png"
        page.screenshot(path=str(screenshot))
        if Image.open(screenshot).convert("RGB").getbbox() is None:
            raise RuntimeError("Flutter Web produced a blank screenshot")
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")

        preview_context = browser.new_context(
            viewport={"width": 200, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        preview_page = preview_context.new_page()
        preview_errors = []
        preview_page.on("pageerror", lambda error: preview_errors.append(str(error)))
        preview_page.goto(
            f"{URL}/?motion=true&scale=1&locale=pt", wait_until="load"
        )
        preview_page.wait_for_timeout(12_000)
        preview_page.mouse.move(160, 400)
        preview_page.mouse.wheel(0, 48)
        preview_page.wait_for_timeout(500)
        with tempfile.TemporaryDirectory(prefix="stroom-resource-badge-") as frame_dir:
            frames = Path(frame_dir)
            for frame in range(60):
                preview_page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                preview_page.wait_for_timeout(250)
            if preview_errors:
                raise RuntimeError(
                    f"Browser reported preview runtime errors: {preview_errors}"
                )
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
                    str(frames / "frame-%03d.png"),
                    "-c:v",
                    "libvpx-vp9",
                    "-b:v",
                    "1M",
                    "-pix_fmt",
                    "yuv420p",
                    str(OUTPUT / "resource-kind-badge-motion-pt-200x640-scale1.webm"),
                ],
                check=True,
            )
        print(
            {
                "screenshot_viewport_css_px": page.viewport_size,
                "preview_viewport_css_px": preview_page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "screenshot_locale": "fr-FR",
                "preview_locale": "pt-BR",
                "theme": "Material 3 light",
                "screenshot_text_scale": 1,
                "preview_text_scale": 1,
                "preview_frames": 60,
                "page_errors": errors + preview_errors,
                "focus": "none",
                "keyboard": "closed",
                "preview_scroll": "resource rows in view",
            }
        )
        preview_context.close()
        browser.close()
finally:
    server.terminate()
    server.wait(timeout=10)
