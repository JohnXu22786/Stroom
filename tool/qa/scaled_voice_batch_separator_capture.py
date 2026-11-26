from io import BytesIO
from pathlib import Path
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs/qa/scaled_voice_batch_separator"
SCALED_SCREENSHOT = OUTPUT_DIR / "separator-de-500x640-scale2_5-light.png"
FITTING_SCREENSHOT = OUTPUT_DIR / "separator-de-700x640-scale1-light.png"
URL = "http://127.0.0.1:8876"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def wait_for_page(page, scale):
    page.goto(
        f"{URL}/?theme=light&textScale={scale}",
        wait_until="load",
        timeout=120_000,
    )
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
    deadline = time.monotonic() + 120
    while True:
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) >= 1:
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("Flutter Web did not render within 120 seconds")
        time.sleep(1)


def select_pipe(page, scale):
    page.locator("flt-semantics-placeholder").focus()
    page.keyboard.press("Enter")
    page.wait_for_function("document.body.innerText.includes('Tabulator')")
    if scale > 1:
        page.mouse.click(200, 175)
    else:
        page.mouse.click(180, 110)
    page.wait_for_timeout(350)
    page.mouse.click(200, 330 if scale > 1 else 250)
    page.wait_for_timeout(500)


def save_screenshot(page, path, expected_size):
    image_bytes = page.screenshot(clip=expected_size[1])
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    if image.size != expected_size[0] or max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError(f"Invalid or blank screenshot: {path.name}, {image.size}")
    path.write_bytes(image_bytes)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )

    errors = []
    scaled = browser.new_page(
        viewport={"width": 500, "height": 640},
        device_scale_factor=1,
    )
    scaled.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_page(scaled, 2.5)
    scaled.wait_for_timeout(1000)
    select_pipe(scaled, 2.5)
    card_clip = {"x": 16, "y": 70, "width": 468, "height": 350}
    save_screenshot(scaled, SCALED_SCREENSHOT, ((468, 350), card_clip))

    fitting = browser.new_page(
        viewport={"width": 700, "height": 640},
        device_scale_factor=1,
    )
    fitting.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_page(fitting, 1)
    fitting.wait_for_timeout(1000)
    select_pipe(fitting, 1)
    save_screenshot(
        fitting,
        FITTING_SCREENSHOT,
        ((668, 250), {"x": 16, "y": 70, "width": 668, "height": 250}),
    )

    print(
        {
            "scaled_screenshot": str(SCALED_SCREENSHOT.relative_to(ROOT)),
            "fitting_screenshot": str(FITTING_SCREENSHOT.relative_to(ROOT)),
            "locale": "de_DE",
            "theme": "light",
            "device_scale_factor": 1,
            "scaled_state": {"viewport": [500, 640], "text_scale": 2.5},
            "fitting_state": {"viewport": [700, 640], "text_scale": 1},
            "focus": "none",
            "keyboard": "closed (headless desktop Chromium)",
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
