from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-flow-card-header"
URL = "http://127.0.0.1:8892"
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
        reduced_motion="reduce",
    )
    page = context.new_page()
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(f"{URL}/?locale=pt-BR", wait_until="load")
    page.wait_for_timeout(3_000)
    page.screenshot(
        path=str(OUTPUT / "flow-block-card-pt-BR-320x640-scale1-light.png")
    )
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    browser.close()
