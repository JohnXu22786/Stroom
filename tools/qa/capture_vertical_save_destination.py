from io import BytesIO
from pathlib import Path
import subprocess
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-save-destination"
SCREENSHOT = OUTPUT / "save-destination-fr-320x640-scale1-light.png"
PREVIEW = OUTPUT / "save-destination-fr-320x640-label-reveal.webm"
FRAMES = OUTPUT / "frames"
URL = "http://127.0.0.1:8897/"
LABEL = "Enregistrer sur l’appareil"
OUTPUT.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)

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
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(URL, wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").evaluate(
        "element => element.click()"
    )
    page.get_by_role("button", name=LABEL).wait_for(timeout=30_000)
    page.wait_for_timeout(250)

    screenshot = page.screenshot()
    rendered = Image.open(BytesIO(screenshot)).convert("RGB")
    if max(ImageStat.Stat(rendered).stddev) < 1:
        raise RuntimeError("Flutter Web did not render the save dialog")
    if page.evaluate("devicePixelRatio") != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    SCREENSHOT.write_bytes(screenshot)

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

    print(
        {
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr_FR",
            "theme": "light Material 3",
            "text_scale": 1,
            "focus": "no focused controls",
            "keyboard": "closed (browser screenshot fixture)",
            "preview_frames": frame_count,
            "page_errors": errors,
        }
    )
    page.close()
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")

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
        str(PREVIEW),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
for frame in FRAMES.glob("frame-*.png"):
    frame.unlink()
FRAMES.rmdir()
