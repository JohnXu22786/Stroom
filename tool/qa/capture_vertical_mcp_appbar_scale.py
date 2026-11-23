from pathlib import Path
import os
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
STATE = Path('/workspace/.cloud-profile-state/vertical_mcp_appbar_scale')
TMP = STATE / 'tmp'
PUB_CACHE = STATE / 'pub-cache'
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/vertical-mcp-appbar-scale'
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
WEB_BUILD.mkdir(parents=True, exist_ok=True)
os.environ['TMPDIR'] = str(TMP)
tempfile.tempdir = str(TMP)

environment = os.environ.copy()
environment['TMPDIR'] = str(TMP)
environment['PUB_CACHE'] = str(PUB_CACHE)
fl_deps = Path('/workspace/toolchains/flutter-linux-deps/env')
environment['PKG_CONFIG_PATH'] = f'{fl_deps}/lib/pkgconfig:{fl_deps}/share/pkgconfig'
environment['PKG_CONFIG_LIBDIR'] = environment['PKG_CONFIG_PATH']
environment['CC'] = str(fl_deps / 'bin/clang')
environment['CXX'] = str(fl_deps / 'bin/clang++')
environment['LD_LIBRARY_PATH'] = str(fl_deps / 'lib')
environment['PATH'] = f"{fl_deps}/bin:{environment['PATH']}"

entrypoint = ROOT / 'tool/qa/vertical_mcp_appbar_scale_capture.dart'
subprocess.run(
    [
        '/workspace/sdks/flutter/bin/flutter',
        'build',
        'web',
        '--no-pub',
        '--release',
        '--no-wasm-dry-run',
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
            raise RuntimeError('Flutter Web server exited before becoming ready')
        try:
            with urlopen(base_url, timeout=1):
                break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError('Flutter Web server did not become ready')

    errors = []
    captures = [
        ('en-US', '1', 'mcp-edit-en-320x640-scale1-light.png'),
        ('de-DE', '1', 'mcp-edit-de-320x640-scale1-light.png'),
        ('de-DE', '2', 'mcp-edit-de-320x640-scale2-light.png'),
    ]
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
        for locale, scale, filename in captures:
            page.goto(
                f'{base_url}?locale={locale}&scale={scale}&theme=light',
                wait_until='load',
                timeout=120_000,
            )
            page.wait_for_timeout(2_000)
            page.mouse.click(268, 76)
            page.wait_for_timeout(800)
            page.screenshot(path=str(OUTPUT / filename))
        browser.close()

    for _, _, filename in captures:
        image = Image.open(OUTPUT / filename)
        if image.size != (320, 640):
            raise RuntimeError(f'Unexpected screenshot size: {image.size}')
        if len(image.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError('Flutter Web produced a blank screenshot')
    if errors:
        raise RuntimeError(f'Browser errors: {errors}')
finally:
    server.terminate()
    server.wait(timeout=10)
