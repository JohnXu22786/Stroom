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
STATE = Path('/workspace/.cloud-profile-state/vertical-drag-pill-scale')
TMP = STATE / 'tmp'
PUB_CACHE = STATE / 'pub-cache'
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/vertical-drag-pill-scale'
ENTRYPOINT = ROOT / 'tool/qa/vertical_drag_pill_scale_capture.dart'
TMP.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment['TMPDIR'] = str(TMP)
environment['PUB_CACHE'] = str(PUB_CACHE)
env = Path('/workspace/toolchains/flutter-linux-deps/env')
environment['PKG_CONFIG_PATH'] = f"{env}/lib/pkgconfig:{env}/share/pkgconfig"
environment['PKG_CONFIG_LIBDIR'] = environment['PKG_CONFIG_PATH']
environment['CC'] = str(env / 'bin/clang')
environment['CXX'] = str(env / 'bin/clang++')
environment['LD_LIBRARY_PATH'] = f"{env}/lib:{environment.get('LD_LIBRARY_PATH', '')}"
environment['PATH'] = f"{env}/bin:{environment['PATH']}"

# Imported production widgets can change without touching this entrypoint.
# Always rebuild so a repeated capture cannot silently use a stale app bundle.
subprocess.run(
    [
        '/workspace/sdks/flutter/bin/flutter',
        'build',
        'web',
        '--no-pub',
        '--release',
        '--no-wasm-dry-run',
        f'--target={ENTRYPOINT}',
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
        captures = [
            (1, 'scale1-light', 'light'),
            (2, 'scale2-light', 'light'),
            (1, 'scale1-dark', 'dark'),
        ]
        for scale, suffix, theme in captures:
            page.goto(
                f'{base_url}?scale={scale}&theme={theme}',
                wait_until='load',
                timeout=120_000,
            )
            page.wait_for_timeout(3_000)
            screenshot = OUTPUT / f'pills-320x640-{suffix}.png'
            page.screenshot(path=str(screenshot))
            image = Image.open(screenshot)
            if image.size != (320, 640):
                raise RuntimeError(f'Unexpected screenshot size: {image.size}')
            if len(image.getcolors(320 * 640) or []) <= 10:
                raise RuntimeError('Flutter did not render the production pill widget')
        browser.close()

    if errors:
        raise RuntimeError(f'Browser reported runtime errors: {errors}')
    print(
        {
            'screenshots': [
                str((OUTPUT / f'pills-320x640-{suffix}.png').relative_to(ROOT))
                for _, suffix, _ in captures
            ],
            'viewport_css_px': {'width': 320, 'height': 640},
            'device_pixel_ratio': 1,
            'locale': 'en-US',
            'themes': {'light': [1, 2], 'dark': [1]},
            'text_scales': [1, 2],
            'focus': 'none',
            'keyboard': 'closed (headless browser)',
            'fixture': 'safe in-memory reasoning options; callbacks are no-ops',
            'page_errors': errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
