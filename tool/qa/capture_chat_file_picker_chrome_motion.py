from pathlib import Path
import math
import shutil
import subprocess
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/chat-file-picker-chrome'
FRAMES = OUTPUT / '.chat-file-picker-motion-frames'
SERVER_LOG = OUTPUT / '.chat-file-picker-web.log'
PREVIEW = OUTPUT / 'chat-file-picker-de-DE-clear-reveal-320x640.webm'
HEAD_CAPTURE = OUTPUT / 'chat-file-picker-de-DE-320x640-scale3-clear-head-browser.png'
TAIL_CAPTURE = OUTPUT / 'chat-file-picker-de-DE-320x640-scale3-clear-tail-browser.png'
RETURN_HEAD_CAPTURE = OUTPUT / 'chat-file-picker-de-DE-320x640-scale3-clear-return-browser.png'
PORT = 8896
URL = f'http://127.0.0.1:{PORT}/?locale=de-DE&scale=3'
VIEWPORT = {'width': 320, 'height': 640}
# The route regression measures 410.003px of text in a 312px slot at 24px/s.
FRAME_RATE = 6
TRAVEL_SECONDS = 4.083
CYCLE_SECONDS = 1 + TRAVEL_SECONDS + 2 + TRAVEL_SECONDS + 2


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(FRAMES, ignore_errors=True)
    FRAMES.mkdir()
    server = subprocess.Popen(
        [
            'flutter', 'run', '--release', '--no-pub', '-d', 'web-server',
            '--web-hostname', '127.0.0.1', '--web-port', str(PORT),
            '--target', 'tool/qa/chat_file_picker_chrome_capture.dart',
        ],
        cwd=ROOT,
        stdout=SERVER_LOG.open('w'),
        stderr=subprocess.STDOUT,
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
        else:
            raise TimeoutError(SERVER_LOG.read_text())

        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path='/usr/bin/chromium',
                args=['--no-sandbox', '--disable-dev-shm-usage'],
            )
            context = browser.new_context(
                viewport=VIEWPORT,
                device_scale_factor=1,
                locale='de-DE',
                reduced_motion='no-preference',
            )
            page = context.new_page()
            page_errors = []
            page.on('pageerror', lambda error: page_errors.append(str(error)))
            page.goto(URL, wait_until='load', timeout=180_000)
            page.locator('flt-semantics-placeholder').wait_for(timeout=120_000)
            page.wait_for_timeout(750)
            page.locator('flt-semantics-placeholder').evaluate('element => element.click()')
            page.wait_for_timeout(250)
            row = page.locator('flt-semantics[aria-label^="picker-chrome-note.txt"]')
            row.wait_for(timeout=30_000)
            page.evaluate('''() => {
              window.__clearFirstRenderedAt = null;
              const recordFirstRender = () => {
                if (window.__clearFirstRenderedAt !== null) return;
                const clear = [...document.querySelectorAll('flt-semantics[role="button"]')]
                    .find(element => element.innerText.includes('Auswahl aufheben (1)'));
                if (clear) window.__clearFirstRenderedAt = performance.now();
              };
              new MutationObserver(recordFirstRender).observe(document.body, {
                subtree: true,
                childList: true,
                characterData: true,
                attributes: true,
              });
              recordFirstRender();
            }''')
            sync_python_before = time.monotonic()
            sync_performance = page.evaluate('performance.now()')
            sync_python_after = time.monotonic()
            sync_python = (sync_python_before + sync_python_after) / 2
            selection_started = time.monotonic()
            row.evaluate('element => element.click()')
            frame_count = math.ceil(CYCLE_SECONDS * FRAME_RATE) + 1
            tail_index = math.ceil((1 + TRAVEL_SECONDS) * FRAME_RATE)
            return_head_index = round(
                (1 + TRAVEL_SECONDS + 2 + TRAVEL_SECONDS) * FRAME_RATE
            )
            raw_frames = []
            first_rendered_at = None
            first_rendered_python = None
            capture_index = 0
            deadline = selection_started + 20
            while time.monotonic() < deadline:
                target = selection_started + capture_index / FRAME_RATE
                delay = target - time.monotonic()
                if delay > 0:
                    time.sleep(delay)
                frame_path = FRAMES / f'raw-{capture_index:04d}.png'
                page.screenshot(path=str(frame_path))
                # A screenshot is only available after Chromium finishes
                # capturing it. Use that time so a slow capture cannot place
                # a later visual state earlier on the video timeline.
                frame_captured_at = time.monotonic()
                raw_frames.append((frame_path, frame_captured_at))
                first_rendered_at = page.evaluate('window.__clearFirstRenderedAt')
                if first_rendered_at is not None and first_rendered_python is None:
                    first_rendered_python = sync_python + (
                        first_rendered_at - sync_performance
                    ) / 1000
                if (
                    first_rendered_python is not None
                    and frame_captured_at >= first_rendered_python + CYCLE_SECONDS
                ):
                    break
                capture_index += 1
            else:
                raise TimeoutError('Clear did not render within 20 seconds of selection')

            if first_rendered_at is None or first_rendered_python is None:
                raise RuntimeError('Clear first-render timestamp was not recorded')

            # Capture starts at the selection click so browser/semantics latency
            # cannot skip the reveal. Rebase the screenshots to the first
            # rendered Clear frame and duplicate only within the initial still.
            frame_paths = {}
            for frame_path, frame_captured_at in raw_frames:
                elapsed = frame_captured_at - first_rendered_python
                frame_index = math.floor(elapsed * FRAME_RATE)
                if 0 <= frame_index < frame_count:
                    frame_paths[frame_index] = frame_path
            if not frame_paths:
                raise RuntimeError('No captured frames followed the Clear render')
            first_frame_index = min(frame_paths)
            first_frame = frame_paths[first_frame_index]
            for frame_index in range(first_frame_index + 1):
                frame_paths[frame_index] = first_frame
            previous_frame = first_frame
            for frame_index in range(frame_count):
                previous_frame = frame_paths.get(frame_index, previous_frame)
                shutil.copyfile(
                    previous_frame,
                    FRAMES / f'frame-{frame_index:04d}.png',
                )
            shutil.copyfile(FRAMES / 'frame-0000.png', HEAD_CAPTURE)
            shutil.copyfile(FRAMES / f'frame-{tail_index:04d}.png', TAIL_CAPTURE)
            shutil.copyfile(
                FRAMES / f'frame-{return_head_index:04d}.png',
                RETURN_HEAD_CAPTURE,
            )
            first_render_capture_delay = (
                raw_frames[next(
                    index
                    for index, (_, frame_captured_at) in enumerate(raw_frames)
                    if frame_captured_at >= first_rendered_python
                )][1]
                - first_rendered_python
            )

            if page_errors:
                raise RuntimeError(f'Browser reported page errors: {page_errors}')
            context.close()
            browser.close()

        subprocess.run(
            [
                'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', str(FRAME_RATE), '-i',
                str(FRAMES / 'frame-%04d.png'),
                '-c:v', 'libvpx-vp9', '-b:v', '1M', '-pix_fmt', 'yuv420p',
                str(PREVIEW),
            ],
            check=True,
            cwd=ROOT,
        )
        duration = float(subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
             '-of', 'csv=p=0', str(PREVIEW)],
            check=True, capture_output=True, text=True,
        ).stdout.strip())
        if duration < CYCLE_SECONDS - 0.3:
            raise RuntimeError(f'Motion preview is short: {duration:.2f}s')
        print({
            'preview': str(PREVIEW.relative_to(ROOT)),
            'viewport': '320x640 logical px',
            'device_pixel_ratio': 1,
            'locale': 'de-DE',
            'text_scale': '3x',
            'frame_rate': FRAME_RATE,
            'frames': frame_count,
            'duration_seconds': round(duration, 2),
            'first_render_capture_delay_seconds': round(
                first_render_capture_delay, 3
            ),
            'page_errors': page_errors,
        })
    finally:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
        shutil.rmtree(FRAMES, ignore_errors=True)
        SERVER_LOG.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
