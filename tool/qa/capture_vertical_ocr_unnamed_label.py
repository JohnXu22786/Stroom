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

from capture_build_dependencies import needs_rebuild


ROOT = Path(__file__).resolve().parents[2]
STATE = Path('/workspace/.cloud-profile-state/vertical_ocr_unnamed_label')
TMP = STATE / 'tmp'
PUB_CACHE = STATE / 'pub-cache'
WEB_BUILD = STATE / 'web-build'
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/vertical-ocr-unnamed-label'
SCREENSHOT = OUTPUT / 'ocr-unnamed-label-en-320x640-scale1-light.png'
PREVIEW = OUTPUT / 'ocr-unnamed-label-motion-preview.webm'
OUTPUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

environment = os.environ.copy()
environment['TMPDIR'] = str(TMP)
environment['PUB_CACHE'] = str(PUB_CACHE)
os.environ['TMPDIR'] = str(TMP)
os.environ['PUB_CACHE'] = str(PUB_CACHE)
toolchain = Path('/workspace/toolchains/flutter-linux-deps/env')
environment['PKG_CONFIG_PATH'] = (
    f'{toolchain}/lib/pkgconfig:{toolchain}/share/pkgconfig'
)
environment['PKG_CONFIG_LIBDIR'] = environment['PKG_CONFIG_PATH']
environment['CC'] = str(toolchain / 'bin/clang')
environment['CXX'] = str(toolchain / 'bin/clang++')
environment['LD_LIBRARY_PATH'] = str(toolchain / 'lib')
environment['PATH'] = f'{toolchain}/bin:{environment["PATH"]}'

entrypoint = ROOT / 'tool/qa/vertical_ocr_unnamed_label_capture.dart'
if not (WEB_BUILD / 'main.dart.js').exists() or needs_rebuild(
    ROOT, entrypoint, WEB_BUILD / 'index.html'
):
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
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path='/usr/bin/chromium',
            args=['--no-sandbox'],
        )
        motion_context = browser.new_context(
            viewport={'width': 320, 'height': 640},
            device_scale_factor=1,
            reduced_motion='no-preference',
        )
        motion_page = motion_context.new_page()
        motion_page.on('pageerror', lambda error: errors.append(str(error)))
        motion_page.goto(base_url, wait_until='load', timeout=120_000)
        motion_page.wait_for_timeout(2_000)
        motion_page.mouse.click(160, 320)
        motion_page.wait_for_timeout(500)
        screenshot_context = browser.new_context(
            viewport={'width': 320, 'height': 640},
            device_scale_factor=1,
            reduced_motion='reduce',
        )
        screenshot_page = screenshot_context.new_page()
        screenshot_page.on('pageerror', lambda error: errors.append(str(error)))
        screenshot_page.goto(base_url, wait_until='load', timeout=120_000)
        screenshot_page.wait_for_timeout(2_000)
        screenshot_page.mouse.click(160, 320)
        screenshot_page.wait_for_timeout(500)
        screenshot_page.screenshot(path=str(SCREENSHOT))
        with tempfile.TemporaryDirectory(
            prefix='ocr-unnamed-label-',
            dir=TMP,
        ) as frame_dir:
            frames = Path(frame_dir)
            for frame in range(36):
                motion_page.screenshot(path=str(frames / f'frame-{frame:03d}.png'))
                motion_page.wait_for_timeout(250)
            subprocess.run(
                [
                    'ffmpeg',
                    '-hide_banner',
                    '-loglevel',
                    'error',
                    '-y',
                    '-framerate',
                    '4',
                    '-i',
                    str(frames / 'frame-%03d.png'),
                    '-c:v',
                    'libvpx-vp9',
                    '-b:v',
                    '500k',
                    '-pix_fmt',
                    'yuv420p',
                    str(PREVIEW),
                ],
                check=True,
            )
        screenshot_context.close()
        motion_context.close()
        browser.close()

    image = Image.open(SCREENSHOT).convert('RGB')
    if image.size != (320, 640):
        raise RuntimeError(f'Unexpected screenshot size: {image.size}')
    if len(image.getcolors(320 * 640) or []) <= 10:
        raise RuntimeError('Flutter did not render the OCR instruction dialog')
    if errors:
        raise RuntimeError(f'Browser reported runtime errors: {errors}')
    print(
        {
            'screenshot': str(SCREENSHOT.relative_to(ROOT)),
            'motion_preview': str(PREVIEW.relative_to(ROOT)),
            'viewport_css_px': {'width': 320, 'height': 640},
            'device_pixel_ratio': 1,
            'locale': 'en-US',
            'theme': 'light',
            'text_scale': 1,
            'focus': 'none',
            'keyboard': 'closed (headless browser)',
            'fixture': 'in-memory unnamed instruction; no request or persistence',
            'page_errors': errors,
        }
    )
finally:
    server.terminate()
    server.wait(timeout=5)
