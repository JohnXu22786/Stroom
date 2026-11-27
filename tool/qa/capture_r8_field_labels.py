from io import BytesIO
from pathlib import Path
import sys

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/ui-constrained-text-qa/r8-field-labels"
BASE_URL = "http://127.0.0.1:8878/"
OUTPUT.mkdir(parents=True, exist_ok=True)

scenes = [
    ("language-search-de-320x640-scale2", "theme", 320, 640, 2, "theme"),
    ("language-search-de-800x900-scale1", "theme", 800, 900, 1, "theme-fit"),
    ("folder-hints-de-360x800-scale2", "folder", 360, 800, 2, "folder"),
    ("folder-hints-de-800x900-scale1", "folder", 800, 900, 1, "folder-fit"),
    ("save-preset-helper-de-320x640-scale1", "batch", 320, 640, 1, "batch"),
    ("save-preset-helper-de-900x720-scale1", "batch", 900, 720, 1, "batch-fit"),
]

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    for filename, scene, width, height, scale, action in scenes:
        page = browser.new_page(
            viewport={"width": width, "height": height},
            device_scale_factor=1,
        )
        page.emulate_media(reduced_motion="reduce")
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(
            f"{BASE_URL}?scene={scene}&locale=de-DE&scale={scale}",
            wait_until="load",
            timeout=120_000,
        )
        page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
        page.wait_for_timeout(2_000)
        if action.startswith("theme"):
            page.get_by_role("textbox").first.scroll_into_view_if_needed()
            page.wait_for_timeout(500)
        elif action.startswith("folder"):
            page.get_by_role("button", name="Neuen Ordner erstellen").click()
            page.wait_for_timeout(500)
        elif action.startswith("batch"):
            page.get_by_role("button", name="Voreinstellung speichern").click()
            page.wait_for_timeout(500)

        screenshot = page.screenshot()
        image = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(image).stddev) < 1:
            raise RuntimeError(f"Flutter Web capture is blank: {filename}")
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError(f"Unexpected device scale: {filename}")
        if errors:
            raise RuntimeError(f"Browser errors in {filename}: {errors}")
        path = OUTPUT / f"{filename}.png"
        path.write_bytes(screenshot)
        print(
            {
                "screenshot": str(path),
                "viewport_css_px": {"width": width, "height": height},
                "device_pixel_ratio": 1,
                "locale": "de-DE",
                "text_scale": scale,
                "scene": action,
                "page_errors": errors,
            }
        )
        page.close()
    browser.close()
