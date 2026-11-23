from io import BytesIO
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
STATE = Path('/workspace/.cloud-profile-state/vertical_backup_info_scroll')
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/vertical-backup-info-scroll'
NORMAL = OUTPUT / 'backup-info-de-DE-320x640-scale1-light.png'
SCALED = OUTPUT / 'backup-info-de-DE-320x640-scale2_5-light.png'
SCALED_SCROLLED = OUTPUT / 'backup-info-de-DE-320x640-scale2_5-light-scrolled.png'

with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    port = listener.getsockname()[1]
server = subprocess.Popen(
    [sys.executable, '-m', 'http.server', str(port), '--bind', '127.0.0.1', '--directory', str(WEB_BUILD)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    base_url = f'http://127.0.0.1:{port}/'
    for _ in range(100):
        if server.poll() is not None:
            raise RuntimeError('Local Flutter Web server exited before becoming ready')
        try:
            urlopen(base_url, timeout=1)
            break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError('Local Flutter Web server did not become ready')

    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path='/usr/bin/chromium',
            args=['--no-sandbox', '--disable-dev-shm-usage'],
        )
        page = browser.new_page(
            viewport={'width': 320, 'height': 640},
            device_scale_factor=1,
            reduced_motion='reduce',
        )
        page.on('pageerror', lambda error: errors.append(str(error)))

        page.goto(f'{base_url}?scale=1', wait_until='load', timeout=120_000)
        page.wait_for_timeout(4_000)
        page.mouse.move(150, 400)
        page.mouse.wheel(0, 800)
        page.wait_for_timeout(500)
        page.mouse.click(248, 368)
        page.wait_for_timeout(700)
        page.screenshot(path=str(NORMAL))

        page.goto(f'{base_url}?scale=2.5', wait_until='load', timeout=120_000)
        page.wait_for_timeout(4_000)
        page.mouse.move(150, 400)
        for _ in range(9):
            page.mouse.wheel(0, 400)
            page.wait_for_timeout(150)
        page.mouse.click(248, 484)
        page.wait_for_timeout(700)
        page.screenshot(path=str(SCALED))
        page.mouse.move(150, 350)
        page.mouse.wheel(0, 600)
        page.wait_for_timeout(500)
        page.screenshot(path=str(SCALED_SCROLLED))
        browser.close()

    for screenshot in (NORMAL, SCALED, SCALED_SCROLLED):
        image = Image.open(BytesIO(screenshot.read_bytes())).convert('RGB')
        if image.size != (320, 640):
            raise RuntimeError(f'Unexpected screenshot size for {screenshot.name}: {image.size}')
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError(f'Flutter did not render {screenshot.name}')
    if errors:
        raise RuntimeError(f'Browser reported runtime errors: {errors}')

    print({
        'screenshots': [str(path.relative_to(ROOT)) for path in (NORMAL, SCALED, SCALED_SCROLLED)],
        'viewport_css_px': {'width': 320, 'height': 640},
        'device_pixel_ratio': 1,
        'locale': 'de-DE',
        'theme': 'light',
        'text_scales': [1, 2.5],
        'focus': 'none',
        'keyboard': 'closed (headless browser)',
        'fixture': 'production BackupRestorePage with in-memory defaults; info dialog is read-only',
        'page_errors': errors,
    })
finally:
    server.terminate()
    server.wait(timeout=5)
