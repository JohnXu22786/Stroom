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
STATE = Path(
    '/workspace/.cloud-profile-state/stroom-guideline-confirmed/round17/'
    'vertical_editor_gutter_scale'
)
TMP = Path('/workspace/t')
PUB_CACHE = STATE / 'pub-cache'
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale'
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment['TMPDIR'] = str(TMP)
environment['PUB_CACHE'] = str(PUB_CACHE)
fl_deps = Path('/workspace/toolchains/flutter-linux-deps/env')
environment['PKG_CONFIG_PATH'] = f"{fl_deps}/lib/pkgconfig:{fl_deps}/share/pkgconfig"
environment['PKG_CONFIG_LIBDIR'] = environment['PKG_CONFIG_PATH']
environment['CC'] = str(fl_deps / 'bin/clang-23')
environment['CXX'] = str(fl_deps / 'bin/clang++-23')
environment['LD_LIBRARY_PATH'] = str(fl_deps / 'lib')
environment['PATH'] = f"{fl_deps}/bin:{environment['PATH']}"

entrypoint = ROOT / 'tool/qa/vertical_editor_gutter_scale_capture.dart'
build_inputs = [entrypoint, ROOT / 'lib/widgets/code_editor_field.dart']
if not (WEB_BUILD / 'index.html').exists() or max(
    path.stat().st_mtime for path in build_inputs
) > (WEB_BUILD / 'index.html').stat().st_mtime:
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
        for scale, filename in (
            ('1', 'editor-gutter-de-320x640-scale1-light.png'),
            ('2', 'editor-gutter-de-320x640-scale2-light.png'),
        ):
            page.goto(
                f'{base_url}?locale=de-DE&scale={scale}&theme=light',
                wait_until='load',
                timeout=120_000,
            )
            page.wait_for_timeout(3_000)
            page.mouse.click(160, 320)
            page.wait_for_timeout(1_000)
            page.screenshot(path=str(OUTPUT / filename))
        browser.close()

    for filename in (
        'editor-gutter-de-320x640-scale1-light.png',
        'editor-gutter-de-320x640-scale2-light.png',
    ):
        screenshot = Image.open(OUTPUT / filename)
        if screenshot.size != (320, 640):
            raise RuntimeError(f'Unexpected screenshot size: {screenshot.size}')
        if len(screenshot.getcolors(320 * 640) or []) <= 10:
            raise RuntimeError('Flutter did not render the JSON editor dialog')
    if errors:
        raise RuntimeError(f'Browser errors: {errors}')
finally:
    server.terminate()
    server.wait(timeout=10)
