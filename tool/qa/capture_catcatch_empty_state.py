from io import BytesIO
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

from capture_render_readiness import navigate_and_wait_for_flutter_render

ROOT = Path(__file__).resolve().parents[2]
BASE_URL = "http://127.0.0.1:8874"
OUTPUT_DIR = ROOT / "docs/qa/catcatch_empty_state"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
EXPECTED_READY_TEXT = "Aucune tâche de téléchargement pour le moment"


def capture(
    browser, name: str, scale: int, scroll: bool, theme: str = "light"
) -> None:
    page = browser.new_page(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    navigate_and_wait_for_flutter_render(
        page,
        f"{BASE_URL}/?locale=fr&theme={theme}&scale={scale}",
        (320, 640),
        EXPECTED_READY_TEXT,
    )

    if scroll:
        page.mouse.move(160, 350)
        page.mouse.wheel(0, 1200)
        page.wait_for_timeout(600)
    image = Image.open(BytesIO(page.screenshot())).convert("RGB")
    if max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError("Flutter Web produced a blank screenshot")
    (OUTPUT_DIR / name).write_bytes(page.screenshot())
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    page.close()


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    capture(browser, "catcatch-empty-state-fr-320x640-1x-light.png", 1, False)
    capture(browser, "catcatch-empty-state-fr-320x640-3x-light-scrolled.png", 3, True)
    capture(browser, "catcatch-empty-state-fr-320x640-1x-dark.png", 1, False, "dark")
    browser.close()
