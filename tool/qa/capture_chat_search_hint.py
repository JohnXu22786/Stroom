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
    captured_at = time.monotonic()
    page.screenshot(path=str(path), clip={
        'x': 0,
        'y': 68 if width > 400 else 76,
        'width': width,
        'height': 70 if width > 400 else 64,
    })
    return captured_at

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
    cycle_duration = 28.0
    frame_rate = 4
    cycle_started = time.monotonic()
    page.get_by_role('button', name='Rechercher dans les messages').evaluate(
            'element => element.click()'
        )
    page.mouse.move(8, 632)
    page.get_by_role('textbox').last.wait_for(state='visible')
    frames = ROOT / 'motion-frames'
    frames.mkdir(exist_ok=True)
    # Capture through the full reveal, endpoint holds, and complete return
    # from the instant the search control is triggered.
    # Schedule screenshots at 4 Hz against monotonic deadlines, then encode
    # their measured timestamps as variable frame durations so screenshot time
    # does not speed up motion. 28 seconds includes the full 2-second hold
    # after the label returns to its leading position.
    frame_paths = []
    frame_times = []
    for index in range(int(cycle_duration * frame_rate)):
        deadline = cycle_started + index / frame_rate
        time.sleep(max(0, deadline - time.monotonic()))
        if time.monotonic() >= cycle_started + cycle_duration:
            break
        frame_path = frames / f'frame-{index:04d}.png'
        frame_paths.append(frame_path)
        frame_times.append(focused_capture(page, frame_path) - cycle_started)
    context.close()
    output_video = ROOT / 'chat-search-hint-fr-reveal-return.webm'
    concat_file = frames / 'frames.txt'
    # The preview timeline starts at the trigger. Hold the first captured
    # leading-position frame for the time spent laying out the hint and
    # capturing that first sample, then preserve every measured frame interval.
    concat_lines = [
        f"file '{frame_paths[0].resolve()}'",
        f'duration {frame_times[0]:.9f}',
    ]
    for index, frame_path in enumerate(frame_paths):
        if index + 1 < len(frame_times):
            duration = frame_times[index + 1] - frame_times[index]
        else:
            duration = cycle_duration - frame_times[index]
        concat_lines.extend((
            f"file '{frame_path.resolve()}'",
            f'duration {duration:.9f}',
        ))
    concat_lines.append(f"file '{frame_paths[-1].resolve()}'")
    concat_file.write_text('\n'.join(concat_lines) + '\n', encoding='utf-8')
    raw_video = ROOT / 'chat-search-hint-fr-reveal-return-raw.webm'
    subprocess.run([
        'ffmpeg', '-y', '-f', 'concat', '-safe', '0', '-i', str(concat_file),
        '-fps_mode', 'vfr', '-t', str(cycle_duration),
        '-c:v', 'libvpx-vp9', '-crf', '30', '-b:v', '0', str(raw_video),
    ], check=True, capture_output=True, text=True)
    raw_duration = float(subprocess.run([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'csv=p=0', str(raw_video),
    ], check=True, capture_output=True, text=True).stdout.strip())
    if abs(raw_duration - cycle_duration) > 0.001:
        final_padding = max(0, cycle_duration - raw_duration)
        command = ['ffmpeg', '-y', '-i', str(raw_video)]
        if final_padding > 0:
            command.extend(('-vf', f'tpad=stop_mode=clone:stop_duration={final_padding:.9f}'))
        command.extend((
            '-fps_mode', 'vfr', '-t', str(cycle_duration),
            '-c:v', 'libvpx-vp9', '-crf', '30', '-b:v', '0', str(output_video),
        ))
        subprocess.run(command, check=True, capture_output=True, text=True)
        raw_video.unlink()
    else:
        raw_video.replace(output_video)
    final_duration = float(subprocess.run([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'csv=p=0', str(output_video),
    ], check=True, capture_output=True, text=True).stdout.strip())
    if abs(final_duration - cycle_duration) > 0.001:
        raise RuntimeError(f'Expected {cycle_duration}s video, got {final_duration}s')
    print({'video_timeline': {
        'frames': len(frame_paths), 'captured_at': [frame_times[0], frame_times[-1]],
        'encoded_duration': final_duration,
    }})
    for frame in frames.iterdir():
        frame.unlink()
    frames.rmdir()
    print({'video': str(output_video), 'errors': errors})

    browser.close()
server.shutdown()
