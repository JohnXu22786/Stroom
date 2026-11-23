from pathlib import Path
from io import BytesIO
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
        frame_times = []
        banner_seen = False
        hidden_frames = 0
        for index in range(500):
            screenshot = page.screenshot(path=str(frames / f"frame-{index:03d}.png"))
            frame_times.append(time.monotonic())
            image = Image.open(BytesIO(screenshot)).convert("RGB")
            card_pixel = image.getpixel((45, 45))
            background_pixel = image.getpixel((45, 120))
            banner_visible = sum(
                abs(card - background)
                for card, background in zip(card_pixel, background_pixel)
            ) > 10
            banner_seen |= banner_visible
            hidden_frames = 0 if banner_visible else hidden_frames + 1
            if banner_seen and hidden_frames >= 5:
                break
            wait = 0.1 - (time.monotonic() - frame_times[-1])
            if wait > 0:
                time.sleep(wait)

        manifest = frames / "frames.txt"
        lines = []
        for index, frame_time in enumerate(frame_times):
            lines.extend([f"file 'frame-{index:03d}.png'\n"])
            next_time = frame_times[min(index + 1, len(frame_times) - 1)]
            duration = next_time - frame_time
            if duration <= 0 and index:
                duration = frame_time - frame_times[index - 1]
            lines.append(f"duration {max(duration, 0.04):.6f}\n")
        lines.append(f"file 'frame-{len(frame_times) - 1:03d}.png'\n")
        manifest.write_text("".join(lines), encoding="utf-8")
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(manifest),
                "-vsync",
                "vfr",
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
