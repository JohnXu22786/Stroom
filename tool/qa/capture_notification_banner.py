from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/vertical_notification_banner"
URL = "http://127.0.0.1:8892"
SCREENSHOTS = {
    "light": OUTPUT / "in-app-notification-en-US-320x640-scale1-light.png",
    "dark": OUTPUT / "in-app-notification-en-US-320x640-scale1-dark.png",
}
PREVIEW = OUTPUT / "in-app-notification-title-reveal.webm"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(f"{URL}/?theme=light", wait_until="load")
    page.wait_for_selector("canvas")
    page.wait_for_timeout(300)
    page.screenshot(path=str(SCREENSHOTS["light"]))

    with tempfile.TemporaryDirectory(prefix="notification-banner-") as tmp:
        frames = Path(tmp)
        # Include the full outbound and return reveal on the production speed.
        for index in range(400):
            page.screenshot(path=str(frames / f"frame-{index:03d}.png"))
            time.sleep(0.1)
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-framerate",
                "10",
                "-i",
                str(frames / "frame-%03d.png"),
                "-c:v",
                "libvpx-vp9",
                "-pix_fmt",
                "yuv420p",
                str(PREVIEW),
            ],
            check=True,
        )

    page.goto(f"{URL}/?theme=dark", wait_until="load")
    page.wait_for_selector("canvas")
    page.wait_for_timeout(300)
    page.screenshot(path=str(SCREENSHOTS["dark"]))
    for screenshot in SCREENSHOTS.values():
        image = Image.open(screenshot).convert("RGB")
        if image.size != (320, 640) or image.getbbox() is None:
            raise RuntimeError(f"Unexpected production screenshot: {screenshot}")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    browser.close()
