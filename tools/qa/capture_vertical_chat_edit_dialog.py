from io import BytesIO
from pathlib import Path
import subprocess
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-chat-edit-dialog"
SCREENSHOT = OUTPUT / "edit-dialog-fr-320x640-scale1-light.png"
SCALED_SCREENSHOT = OUTPUT / "edit-dialog-fr-320x640-scale2-light.png"
FRAMES = OUTPUT / "frames"
URL = "http://127.0.0.1:8879/?locale=fr&theme=light"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    errors = []
    for scale, screenshot_path in ((1, SCREENSHOT), (2, SCALED_SCREENSHOT)):
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(f"{URL}&scale={scale}", wait_until="load", timeout=120_000)
        page.wait_for_timeout(3_000)
        page.locator("flt-semantics-placeholder").evaluate(
            "element => element.click()"
        )
        page.get_by_role("button", name="Éditeur plein écran").click(
            timeout=30_000
        )
        page.get_by_role("button", name="Fermer").wait_for(timeout=30_000)
        page.wait_for_timeout(150)

        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) < 1:
            raise RuntimeError(f"Flutter Web did not render the dialog at {scale}×")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        screenshot_path.write_bytes(screenshot)

        if scale == 2:
            duration_seconds = 9
            frames_per_second = 8
            frame_count = duration_seconds * frames_per_second
            frame_interval = 1 / frames_per_second
            start = time.monotonic()
            for index in range(frame_count):
                page.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
                target = start + (index + 1) * frame_interval
                delay = target - time.monotonic()
                if delay > 0:
                    time.sleep(delay)
        page.close()

    print(
        {
            "screenshot_1x": str(SCREENSHOT.relative_to(ROOT)),
            "scaled_screenshot_2x": str(SCALED_SCREENSHOT.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr_FR",
            "theme": "light Material 3",
            "text_scales": [1, 2],
            "focus": "editor TextField autofocus",
            "keyboard": "closed (browser screenshot fixture)",
            "preview_frames": frame_count,
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")

subprocess.run(
    [
        "ffmpeg",
        "-y",
        "-framerate",
        "8",
        "-i",
        str(FRAMES / "frame-%03d.png"),
        "-c:v",
        "libvpx-vp9",
        "-pix_fmt",
        "yuv420p",
        "-b:v",
        "500k",
        str(OUTPUT / "edit-dialog-heading-motion.webm"),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()
FRAMES.rmdir()
