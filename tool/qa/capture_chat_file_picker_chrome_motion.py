import shutil
import subprocess
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'docs/ui-constrained-text-qa/chat-file-picker-chrome'
PREVIEW = OUTPUT / 'chat-file-picker-de-DE-clear-reveal-320x640.webm'
FONT_SIZE = 42
TEXT = 'Auswahl aufheben (1)'
BACKGROUND = (254, 247, 255)
FOREGROUND = (103, 80, 164)
FPS = 4


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    flutter_wrapper = Path(shutil.which('flutter'))
    revision = re.search(r'sdk_revision="([^"]+)"', flutter_wrapper.read_text())
    if revision is None:
        raise RuntimeError('Could not find the Flutter SDK revision')
    flutter_root = Path('/tmp/codex-build-cache') / f'flutter-sdk-{revision.group(1)}'
    font_path = flutter_root / 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'
    font = ImageFont.truetype(str(font_path), FONT_SIZE)
    text_width = font.getlength(TEXT)
    slot_left, slot_right = 4, 316
    slot_width = slot_right - slot_left
    travel_seconds = (text_width - slot_width) / 24
    start = Image.open(
        OUTPUT / 'chat-file-picker-de-DE-320x640-scale3-light.png'
    ).convert('RGB')
    frames_path = OUTPUT / '.chat-file-picker-motion-frames'
    shutil.rmtree(frames_path, ignore_errors=True)
    frames_path.mkdir()

    # Keep the actual production route capture as the frame backdrop. Repaint
    # only the constrained Clear label with the route's Roboto size, color,
    # measured slot width, and the shared widget's 24 logical px/s timing.
    frame_count = round((1 + travel_seconds + 2) * FPS)
    for frame_index in range(frame_count + 1):
        seconds = frame_index / FPS
        if seconds <= 1:
            offset = 0
        elif seconds < 1 + travel_seconds:
            offset = min(24 * (seconds - 1), text_width - slot_width)
        else:
            offset = text_width - slot_width
        image = start.copy()
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 64, 319, 120), fill=BACKGROUND)
        draw.text((slot_left - offset, 73), TEXT, font=font, fill=FOREGROUND)
        image.save(frames_path / f'frame-{frame_index:04d}.png')

    subprocess.run(
        [
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-framerate', str(FPS), '-i', str(frames_path / 'frame-%04d.png'),
            '-c:v', 'libvpx-vp9', '-b:v', '1M', '-pix_fmt', 'yuv420p',
            str(PREVIEW),
        ],
        check=True,
    )
    duration = float(subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
         '-of', 'csv=p=0', str(PREVIEW)],
        check=True, capture_output=True, text=True,
    ).stdout.strip())
    shutil.rmtree(frames_path)
    print({
        'preview': str(PREVIEW.relative_to(ROOT)),
        'frame_rate': FPS,
        'duration_seconds': round(duration, 2),
        'travel_seconds': round(travel_seconds, 2),
        'text_width': round(text_width, 1),
        'slot_width': slot_width,
    })


if __name__ == '__main__':
    main()
