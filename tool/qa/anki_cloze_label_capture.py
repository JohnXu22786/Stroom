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
WEB_BUILD = Path('/tmp/stroom-anki-cloze-web')
OUTPUT = ROOT / 'docs/qa/anki_cloze_label'
SCREENSHOT = OUTPUT / 'anki-cloze-de-320x640-1x-light-focused.png'
PREVIEW = OUTPUT / 'anki-cloze-de-label-reveal-320x640-light.webm'
OUTPUT.mkdir(parents=True, exist_ok=True)

with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    port = listener.getsockname()[1]

server = subprocess.Popen(
    [sys.executable, '-m', 'http.server', str(port), '--bind', '127.0.0.1', '--directory', str(WEB_BUILD)],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    base_url = f'http://127.0.0.1:{port}/?scale=1'
    for _ in range(100):
        if server.poll() is not None:
            raise RuntimeError('Local Flutter Web server exited before becoming ready')
        try:
            with urlopen(base_url, timeout=1):
                break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError('Local Flutter Web server did not become ready')

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path='/usr/bin/chromium',
            args=['--no-sandbox', '--disable-dev-shm-usage'],
        )

        def open_cloze(page):
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto(base_url, wait_until='load', timeout=120_000)
            page.wait_for_timeout(7000)
            page.mouse.click(272, 108)
            page.wait_for_timeout(1200)
            page.mouse.click(180, 120)
            page.wait_for_timeout(1800)
            page.screenshot(path='/tmp/anki-basic-dialog.png')
            page.mouse.click(160, 175)
            page.wait_for_timeout(800)
            page.screenshot(path='/tmp/anki-model-menu.png')
            page.mouse.click(160, 220)
            page.wait_for_timeout(1800)
            if errors:
                raise RuntimeError(f'Browser reported runtime errors: {errors}')
            return errors

        still_page = browser.new_page(viewport={'width': 320, 'height': 640}, device_scale_factor=1)
        open_cloze(still_page)
        still_page.screenshot(path=str(SCREENSHOT))
        still_page.close()

        video_page = browser.new_page(
            viewport={'width': 320, 'height': 640},
            device_scale_factor=1,
            record_video_dir=str(OUTPUT),
            record_video_size={'width': 320, 'height': 640},
        )
        open_cloze(video_page)
        video_page.wait_for_timeout(8500)
        video = video_page.video
        video_page.close()
        raw_video = Path(video.path())
        subprocess.run(
            [
                'ffmpeg', '-y', '-ss', '12.5', '-i', str(raw_video), '-t', '8.5',
                '-c:v', 'libvpx-vp9', '-an', str(PREVIEW), '-loglevel', 'error',
            ],
            check=True,
        )
        raw_video.unlink()

        image = Image.open(BytesIO(SCREENSHOT.read_bytes())).convert('RGB')
        if image.size != (320, 640):
            raise RuntimeError(f'Unexpected screenshot size: {image.size}')
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError('Flutter did not render the card dialog screenshot')
        print({
            'screenshot': str(SCREENSHOT.relative_to(ROOT)),
            'preview': str(PREVIEW.relative_to(ROOT)),
            'viewport_css_px': {'width': 320, 'height': 640},
            'device_pixel_ratio': 1,
            'locale': 'de-DE',
            'theme': 'light',
            'text_scale': 1,
            'focus': 'Cloze text field (autofocus)',
            'keyboard': 'closed (headless browser)',
            'fixture': 'in-memory deck and Basic/Cloze note types; no submit/network/database calls',
        })
        browser.close()
finally:
    server.terminate()
    server.wait(timeout=5)
