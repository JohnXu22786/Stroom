from pathlib import Path
import os
import shutil
import subprocess
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'docs/qa/anki_sync_overwrite_button'
VIDEO_DIR = OUTPUT / '.video-tmp'
SERVER_LOG = OUTPUT / '.animation-capture.log'
PORT = 8898
URL = f'http://127.0.0.1:{PORT}/'
OUTPUT.mkdir(parents=True, exist_ok=True)
VIDEO_DIR.mkdir(parents=True, exist_ok=True)

with SERVER_LOG.open('w') as log:
    server = subprocess.Popen(
        [
            'flutter', 'run', '--no-pub', '-d', 'web-server',
            '--web-hostname', '127.0.0.1', '--web-port', str(PORT),
            '--target', 'tool/qa/anki_sync_overwrite_button_animation_capture.dart',
        ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=os.environ.copy()
    )
    try:
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            if server.poll() is not None:
                raise RuntimeError(SERVER_LOG.read_text())
            try:
                with urlopen(URL, timeout=1):
                    if 'is being served at' in SERVER_LOG.read_text():
                        break
            except Exception:
                time.sleep(1)
            time.sleep(1)
        else:
            raise TimeoutError(SERVER_LOG.read_text())

        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True, executable_path='/usr/bin/chromium',
                args=['--no-sandbox', '--disable-dev-shm-usage'],
            )
            context = browser.new_context(
                viewport={'width': 320, 'height': 640},
                device_scale_factor=1,
                reduced_motion='no-preference',
            )
            page = context.new_page()
            page.goto(URL, wait_until='load', timeout=120_000)
            page.wait_for_timeout(1_500)
            page.screenshot(path=str(OUTPUT / 'animation-start.png'))
            frame_rate = 6
            started = time.monotonic()
            for index in range(60):
                page.screenshot(path=str(VIDEO_DIR / f'frame-{index:03d}.png'))
                delay = started + (index + 1) / frame_rate - time.monotonic()
                if delay > 0:
                    time.sleep(delay)
            page.screenshot(path=str(OUTPUT / 'animation-end.png'))
            context.close()
            browser.close()
            subprocess.run(
                [
                    'ffmpeg', '-y', '-framerate', str(frame_rate),
                    '-i', str(VIDEO_DIR / 'frame-%03d.png'),
                    '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuv420p',
                    str(OUTPUT / 'overwrite-server-reveal-de-DE-320x640-1x-light.webm'),
                ], check=True, cwd=ROOT,
            )
    finally:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
        SERVER_LOG.unlink(missing_ok=True)
        shutil.rmtree(VIDEO_DIR, ignore_errors=True)
