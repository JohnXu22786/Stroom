from pathlib import Path
from playwright.sync_api import sync_playwright

OUTPUT = Path('docs/qa/markdown_list_marker_bounds')
OUTPUT.mkdir(parents=True, exist_ok=True)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path='/usr/bin/chromium', args=['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader'])
    page = browser.new_page(viewport={"width": 320, "height": 640}, device_scale_factor=1)
    page.goto('http://127.0.0.1:8765/', wait_until='networkidle')
    page.wait_for_timeout(5000)
    page.screenshot(path=str(OUTPUT / 'ordered-markers-320x640-1x.png'))
    browser.close()
