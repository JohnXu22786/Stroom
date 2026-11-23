from io import BytesIO
from pathlib import Path
import subprocess
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-guidelines/images/ui-constrained-text-qa/vertical-provider-badges"
FRAMES = OUTPUT / "frames"
BASE_URL = "http://127.0.0.1:8883/?theme=light"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)


def open_page(browser, scale, capture_width=320):
    page = browser.new_page(
        viewport={"width": 1000, "height": 640},
        device_scale_factor=1,
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(f"{BASE_URL}&scale={scale}", wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").evaluate(
        "element => element.click()"
    )
    page.wait_for_timeout(300)
    page.evaluate("() => document.fonts.ready")
    page.wait_for_timeout(250)
    page.mouse.move(500, 520)
    page.mouse.wheel(0, 3000)
    page.wait_for_timeout(100)
    if capture_width == 320:
        page.set_viewport_size({"width": 320, "height": 640})
        if scale > 1:
            page.mouse.move(160, 520)
            page.mouse.wheel(0, 1100)
        page.wait_for_timeout(150)
    if page.evaluate("devicePixelRatio") != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    return page, errors


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    page_errors = []
    for scale, width, filename in (
        (1, 1000, "provider-badges-de-1000x640-scale1-light.png"),
        (1, 320, "provider-badges-de-320x640-scale1-light.png"),
        (1.8, 320, "provider-badges-de-320x640-scale1_8-light.png"),
    ):
        page, errors = open_page(browser, scale, capture_width=width)
        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) < 1:
            raise RuntimeError(f"Flutter Web did not render the page at {scale}×")
        (OUTPUT / filename).write_bytes(screenshot)
        page_errors.extend(errors)
        page.close()

    preview, errors = open_page(browser, 1.8)
    page_errors.extend(errors)
    duration_seconds = 17
    frames_per_second = 8
    frame_count = duration_seconds * frames_per_second
    start = time.monotonic()
    for index in range(frame_count):
        preview.screenshot(path=str(FRAMES / f"frame-{index:03d}.png"))
        delay = start + (index + 1) / frames_per_second - time.monotonic()
        if delay > 0:
            time.sleep(delay)
    preview.close()
    browser.close()

if page_errors:
    raise RuntimeError(f"Browser reported runtime errors: {page_errors}")

subprocess.run(
    [
        "ffmpeg",
        "-y",
        "-framerate",
        str(frames_per_second),
        "-i",
        str(FRAMES / "frame-%03d.png"),
        "-c:v",
        "libvpx-vp9",
        "-pix_fmt",
        "yuv420p",
        "-b:v",
        "500k",
        str(OUTPUT / "provider-badge-motion-preview.webm"),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()
FRAMES.rmdir()

print(
    {
        "output": str(OUTPUT.relative_to(ROOT)),
        "viewport_css_px": "1000 × 640 wide capture plus 320 × 640 narrow captures",
        "device_pixel_ratio": 1,
        "locale": "de-DE",
        "theme": "light Material 3",
        "text_scales": [1, 1.8],
        "focus": "none",
        "keyboard": "closed",
        "preview_frames": frame_count,
        "page_errors": page_errors,
    }
)
