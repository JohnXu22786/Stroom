from pathlib import Path
import subprocess
import tempfile

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/catcatch-media-metadata"
URL = "http://127.0.0.1:8879"
OUTPUT.mkdir(parents=True, exist_ok=True)


def open_fixture(page, *, motion):
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(
        f"{URL}/?motion={str(motion).lower()}",
        wait_until="load",
    )
    page.wait_for_timeout(12_000)
    return errors


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
    errors = open_fixture(page, motion=False)
    screenshot = OUTPUT / "catcatch-media-metadata-de-320x640-1x-light.png"
    page.screenshot(path=str(screenshot))
    if Image.open(screenshot).convert("RGB").getbbox() is None:
        raise RuntimeError("Flutter Web produced a blank screenshot")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    browser.close()

with tempfile.TemporaryDirectory(prefix="stroom-catcatch-media-metadata-") as frame_dir:
    frames = Path(frame_dir)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        context = browser.new_context(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        page = context.new_page()
        errors = open_fixture(page, motion=True)
        for frame in range(36):
            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
            page.wait_for_timeout(250)
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        print(
            {
                "viewport_css_px": page.viewport_size,
                "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                "locale": "de_DE",
                "theme": "light",
                "text_scale": 1,
                "preview_frames": 36,
                "page_errors": errors,
            }
        )
        browser.close()
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
            str(OUTPUT / "catcatch-media-metadata-motion-320x640.webm"),
        ],
        check=True,
    )
