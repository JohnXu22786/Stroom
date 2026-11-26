from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs/qa/scaled_voice_batch_separator"
SCALED_SCREENSHOT = OUTPUT_DIR / "separator-de-500x640-scale2_5-light.png"
CLIPPED_SCREENSHOT = OUTPUT_DIR / "separator-de-320x640-scale2_5-light.png"
FITTING_SCREENSHOT = OUTPUT_DIR / "separator-de-700x640-scale1-light.png"
PREVIEW = OUTPUT_DIR / "separator-de-320x640-scale2_5-reveal.webm"
URL = "http://127.0.0.1:8876"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def wait_for_page(page, scale):
    page.goto(
        f"{URL}/?theme=light&textScale={scale}",
        wait_until="load",
        timeout=120_000,
    )
    page.locator("flt-semantics-placeholder").wait_for(timeout=120_000)
    deadline = time.monotonic() + 120
    while True:
        rendered = Image.open(BytesIO(page.screenshot())).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) >= 1:
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("Flutter Web did not render within 120 seconds")
        time.sleep(1)


def select_pipe(page, scale):
    page.locator("flt-semantics-placeholder").focus()
    page.keyboard.press("Enter")
    page.wait_for_function("document.body.innerText.includes('Tabulator')")
    if scale > 1:
        page.mouse.click(200, 175)
    else:
        page.mouse.click(180, 110)
    page.wait_for_timeout(350)
    page.mouse.click(200, 330 if scale > 1 else 250)
    page.wait_for_timeout(500)


def save_screenshot(page, path, expected_size):
    image_bytes = page.screenshot(clip=expected_size[1])
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    if image.size != expected_size[0] or max(ImageStat.Stat(image).stddev) < 1:
        raise RuntimeError(f"Invalid or blank screenshot: {path.name}, {image.size}")
    path.write_bytes(image_bytes)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )

    errors = []
    scaled = browser.new_page(
        viewport={"width": 500, "height": 640},
        device_scale_factor=1,
    )
    scaled.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_page(scaled, 2.5)
    scaled.wait_for_timeout(1000)
    select_pipe(scaled, 2.5)
    card_clip = {"x": 16, "y": 70, "width": 468, "height": 350}
    save_screenshot(scaled, SCALED_SCREENSHOT, ((468, 350), card_clip))

    clipped = browser.new_page(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
    )
    clipped.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_page(clipped, 2.5)
    clipped.wait_for_timeout(1000)
    select_pipe(clipped, 2.5)
    clipped_card = {"x": 16, "y": 70, "width": 288, "height": 350}
    save_screenshot(
        clipped,
        CLIPPED_SCREENSHOT,
        ((288, 350), clipped_card),
    )

    frame_rate = 10
    preview_duration = 9
    with tempfile.TemporaryDirectory(
        prefix="voice-batch-separator-frames-", dir=OUTPUT_DIR
    ) as frame_directory:
        frame_directory = Path(frame_directory)
        deadline = time.monotonic() + preview_duration
        frame_number = 0
        next_frame = time.monotonic()
        while time.monotonic() < deadline:
            (frame_directory / f"frame-{frame_number:04d}.png").write_bytes(
                clipped.screenshot(clip=clipped_card)
            )
            frame_number += 1
            next_frame += 1 / frame_rate
            clipped.wait_for_timeout(
                max(0, round((next_frame - time.monotonic()) * 1000))
            )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-framerate",
                str(frame_rate),
                "-i",
                str(frame_directory / "frame-%04d.png"),
                "-c:v",
                "libvpx-vp9",
                "-deadline",
                "good",
                "-cpu-used",
                "4",
                "-b:v",
                "0",
                "-crf",
                "32",
                "-pix_fmt",
                "yuv420p",
                "-an",
                str(PREVIEW),
            ],
            check=True,
        )

    fitting = browser.new_page(
        viewport={"width": 700, "height": 640},
        device_scale_factor=1,
    )
    fitting.on("pageerror", lambda error: errors.append(str(error)))
    wait_for_page(fitting, 1)
    fitting.wait_for_timeout(1000)
    select_pipe(fitting, 1)
    save_screenshot(
        fitting,
        FITTING_SCREENSHOT,
        ((668, 140), {"x": 16, "y": 70, "width": 668, "height": 140}),
    )

    print(
        {
            "scaled_screenshot": str(SCALED_SCREENSHOT.relative_to(ROOT)),
            "clipped_screenshot": str(CLIPPED_SCREENSHOT.relative_to(ROOT)),
            "fitting_screenshot": str(FITTING_SCREENSHOT.relative_to(ROOT)),
            "preview": str(PREVIEW.relative_to(ROOT)),
            "locale": "de_DE",
            "theme": "light",
            "device_scale_factor": 1,
            "scaled_state": {"viewport": [500, 640], "text_scale": 2.5},
            "clipped_state": {"viewport": [320, 640], "text_scale": 2.5},
            "fitting_state": {"viewport": [700, 640], "text_scale": 1},
            "focus": "none",
            "keyboard": "closed (headless desktop Chromium)",
            "preview_duration_seconds": preview_duration,
            "preview_frames_per_second": frame_rate,
            "page_errors": errors,
        }
    )
    browser.close()

if errors:
    raise RuntimeError(f"Browser reported runtime errors: {errors}")
