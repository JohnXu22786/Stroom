from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from threading import Thread
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
BUILD = Path('/tmp/stroom-ocr-batch-mode-web')
OUTPUTS = [
    (
        'http://127.0.0.1:8874/?scale=1',
        {'width': 320, 'height': 640},
        'ocr-batch-de-320x640-1x-light.png',
        1,
    ),
    (
        'http://127.0.0.1:8874/?scale=2',
        {'width': 600, 'height': 1000},
        'ocr-batch-de-600x1000-2x-light.png',
        2,
    ),
]


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format, *_args):
        pass


server = ThreadingHTTPServer(
    ('127.0.0.1', 8874),
    lambda *args, **kwargs: QuietHandler(
        *args, directory=str(BUILD), **kwargs
    ),
)
Thread(target=server.serve_forever, daemon=True).start()
time.sleep(0.2)

results = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path='/usr/bin/chromium',
        args=['--no-sandbox', '--disable-dev-shm-usage'],
    )
    for url, viewport, filename, text_scale in OUTPUTS:
        page = browser.new_page(viewport=viewport, device_scale_factor=1)
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(url, wait_until='load', timeout=120_000)
        page.locator('flt-semantics-placeholder').wait_for(timeout=120_000)

        deadline = time.monotonic() + 120
        while True:
            screenshot = page.screenshot()
            rendered = Image.open(BytesIO(screenshot)).convert('RGB')
            if max(ImageStat.Stat(rendered).stddev) >= 1:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Flutter Web did not render within 120 seconds')
            time.sleep(1)

        output = ROOT / 'docs/qa/ocr_batch_mode' / filename
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(screenshot)
        results.append(
            {
                'output': str(output.relative_to(ROOT)),
                'viewport_css_px': viewport,
                'device_pixel_ratio': 1,
                'locale': 'de_DE',
                'theme': 'light',
                'text_scale': text_scale,
                'page_errors': errors,
            }
        )
        page.close()
    browser.close()
server.shutdown()

for result in results:
    print(result)
    if result['page_errors']:
        raise RuntimeError(f"Browser reported runtime errors: {result['page_errors']}")
