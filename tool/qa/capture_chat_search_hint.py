from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
import subprocess
import time

from playwright.sync_api import sync_playwright

ROOT = Path('docs/ui-constrained-text-qa/chat-search-hint')
ROOT.mkdir(parents=True, exist_ok=True)
WEB = Path('/tmp/chat-search-hint-web')
PORT = 8894

def focused_capture(page, path):
    width = page.viewport_size['width']
    page.screenshot(path=str(path), clip={
        'x': 0,
        'y': 68 if width > 400 else 76,
        'width': width,
        'height': 70 if width > 400 else 90,
    })

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

server = ThreadingHTTPServer(('127.0.0.1', PORT), lambda *a, **kw: Handler(*a, directory=WEB, **kw))
Thread(target=server.serve_forever, daemon=True).start()
time.sleep(0.2)

with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path='/usr/bin/chromium',
        args=['--no-sandbox', '--disable-dev-shm-usage'],
    )

    def open_page(locale, scale, theme, width=320, height=640, motion='off', record=False):
        context_args = {'viewport': {'width': width, 'height': height}, 'device_scale_factor': 1}
        context = browser.new_context(**context_args)
        page = context.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(
            f'http://127.0.0.1:{PORT}/?locale={locale}&scale={scale}&theme={theme}&motion={motion}',
            wait_until='load', timeout=120_000,
        )
        page.locator('flt-semantics-placeholder').wait_for(timeout=120_000)
        page.wait_for_timeout(5000)
        page.locator('flt-semantics-placeholder').evaluate('element => element.click()')
        page.mouse.move(8, height - 8)
        return context, page, errors

    for theme in ('light', 'dark'):
        context, page, errors = open_page('fr-FR', 2, theme)
        page.get_by_role('button', name='Rechercher dans les messages').evaluate(
            'element => element.click()'
        )
        page.wait_for_timeout(500)
        page.mouse.move(8, page.viewport_size['height'] - 8)
        page.wait_for_timeout(1800)
        focused_capture(page, ROOT / f'chat-search-hint-fr-320x640-scale2-{theme}.png')
        print({'screenshot': theme, 'errors': errors})
        context.close()

    context, page, errors = open_page('de-DE', 1, 'light')
    page.get_by_role('button', name='Nachrichten suchen').evaluate(
        'element => element.click()'
    )
    page.mouse.move(8, 632)
    page.wait_for_timeout(1800)
    focused_capture(page, ROOT / 'chat-search-hint-de-320x640-scale1-light.png')
    print({'screenshot': 'alternate locale', 'errors': errors})
    context.close()

    context, page, errors = open_page('en-US', 1, 'light', width=1000, height=700)
    page.get_by_role('button', name='Search messages').evaluate(
        'element => element.click()'
    )
    page.wait_for_timeout(500)
    focused_capture(page, ROOT / 'chat-search-hint-en-1000x700-scale1-light.png')
    print({'screenshot': 'fitting', 'errors': errors})
    context.close()

    context, page, errors = open_page('fr-FR', 2, 'light', motion='on')
    page.get_by_role('button', name='Rechercher dans les messages').evaluate(
            'element => element.click()'
        )
    page.mouse.move(8, 632)
    page.wait_for_timeout(200)
    frames = ROOT / 'motion-frames'
    frames.mkdir(exist_ok=True)
    # The French 2× label travels about nine seconds in each direction.
    # Capture one full 23-second cycle, including the initial delay, both
    # 2-second endpoint holds, and complete return, at four frames per second.
    for index in range(92):
        focused_capture(page, frames / f'frame-{index:04d}.png')
        page.wait_for_timeout(250)
    context.close()
    output_video = ROOT / 'chat-search-hint-fr-reveal-return.webm'
    subprocess.run([
        'ffmpeg', '-y', '-framerate', '4', '-i', str(frames / 'frame-%04d.png'),
        '-c:v', 'libvpx-vp9', '-crf', '30', '-b:v', '0', str(output_video),
    ], check=True, capture_output=True, text=True)
    for frame in frames.iterdir():
        frame.unlink()
    frames.rmdir()
    print({'video': str(output_video), 'errors': errors})

    browser.close()
server.shutdown()
