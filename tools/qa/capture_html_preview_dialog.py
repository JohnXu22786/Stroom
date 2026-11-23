from io import BytesIO
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/html-preview-dialog"
SCREENSHOT = OUTPUT / "html-preview-zh-320x640-scale1-light.png"
URL = "http://127.0.0.1:8898/"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(URL, wait_until="load", timeout=120_000)
    page.locator("flt-semantics-placeholder").evaluate(
        "element => element.click()"
    )
    page.get_by_role("button", name="Open preview").click(timeout=30_000)
    page.get_by_role("button", name="编辑").wait_for(timeout=30_000)
    page.get_by_role("button", name="关闭预览").wait_for(timeout=30_000)
    page.wait_for_timeout(250)

    screenshot = page.screenshot()
    rendered = Image.open(BytesIO(screenshot)).convert("RGB")
    if max(ImageStat.Stat(rendered).stddev) < 1:
        raise RuntimeError("Flutter Web did not render the HTML preview dialog")
    if page.evaluate("devicePixelRatio") != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    SCREENSHOT.write_bytes(screenshot)
    print(
        {
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "zh_CN",
            "theme": "light Material 3",
            "text_scale": 1,
            "focus": "no focused controls",
            "keyboard": "closed (browser screenshot fixture)",
            "fixture": "local HTML only; no account data or network request",
            "page_errors": errors,
        }
    )
    page.close()
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
