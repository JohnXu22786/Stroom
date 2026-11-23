from pathlib import Path
import os
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
STATE = Path('/workspace/.cloud-profile-state/vertical_mcp_arguments_hint')
TMP = STATE / 't'
PUB_CACHE = STATE / 'pub-cache'
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/vertical-mcp-arguments-hint'
SCREENSHOT = OUTPUT / 'mcp-arguments-hint-en-320x640-scale1-light.png'
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
os.environ['TMPDIR'] = str(TMP)

environment = os.environ.copy()
environment['TMPDIR'] = str(TMP)
environment['XDG_CACHE_HOME'] = str(STATE / 'xdg-cache')
environment['PUB_CACHE'] = str(PUB_CACHE)
env = Path('/workspace/toolchains/flutter-linux-deps/env')
environment['PKG_CONFIG_PATH'] = f'{env}/lib/pkgconfig:{env}/share/pkgconfig'
environment['PKG_CONFIG_LIBDIR'] = environment['PKG_CONFIG_PATH']
environment['CC'] = str(env / 'bin/clang')
environment['CXX'] = str(env / 'bin/clang++')
environment['LD_LIBRARY_PATH'] = str(env / 'lib')
environment['PATH'] = f'{env}/bin:{environment["PATH"]}'

entrypoint = ROOT / 'tool/qa/mcp_arguments_hint_capture.dart'
subprocess.run(
    [
        '/workspace/sdks/flutter/bin/flutter',
        'build',
        'web',
        '--no-pub',
        '--release',
        f'--target={entrypoint}',
        f'--output={WEB_BUILD}',
    ],
    cwd=ROOT,
    env=environment,
    check=True,
)

with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    port = listener.getsockname()[1]

server = subprocess.Popen(
    [
        sys.executable,
        '-m',
        'http.server',
        str(port),
        '--bind',
        '127.0.0.1',
        '--directory',
        str(WEB_BUILD),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    base_url = f'http://127.0.0.1:{port}/'
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
        page.goto(base_url, wait_until='load', timeout=120_000)
        page.wait_for_function(
            "document.documentElement.hasAttribute("
            "'data-mcp-capture-launcher-ready')",
            timeout=30_000,
        )
        page.mouse.click(160, 320)
        page.wait_for_function(
            "document.documentElement.hasAttribute("
            "'data-mcp-arguments-dialog-ready')",
            timeout=30_000,
        )
        # The stdio option is the left transport choice near the top of the
        # dialog. Keep the page unfocused so the capture shows helper wrapping
        # without a software keyboard covering the content.
        page.mouse.click(94, 172)
        page.wait_for_timeout(500)
        page.mouse.move(160, 480)
        page.mouse.wheel(0, 260)
        page.wait_for_timeout(500)
        if not page.locator('html').get_attribute(
            'data-mcp-arguments-dialog-ready'
        ):
            raise RuntimeError('MCP configuration dialog did not open')
        page.get_by_text(
            'Separate arguments with commas, for example: -y, '
            '@modelcontextprotocol/server-filesystem, /tmp',
            exact=True,
        ).wait_for(timeout=10_000)
        page.screenshot(path=str(SCREENSHOT))
        browser.close()

    image = Image.open(SCREENSHOT)
    if image.size != (320, 640):
        raise RuntimeError(f'Unexpected screenshot size: {image.size}')
    if len(image.getcolors(320 * 640) or []) <= 10:
        raise RuntimeError('Flutter did not render the MCP configuration dialog')
    if errors:
        raise RuntimeError(f'Browser reported runtime errors: {errors}')
    print(
        {
            'screenshot': str(SCREENSHOT.relative_to(ROOT)),
            'viewport_css_px': {'width': 320, 'height': 640},
            'device_pixel_ratio': 1,
            'locale': 'en-US',
            'theme': 'light',
            'text_scale': 1,
            'focus': 'no text field focused',
            'keyboard': 'closed (headless browser)',
            'fixture': 'empty in-memory provider config; no account data or provider request',
            'page_errors': errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
