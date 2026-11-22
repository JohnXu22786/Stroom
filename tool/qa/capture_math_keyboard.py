from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/math-keyboard"
URL = "http://127.0.0.1:8878"
OUTPUT.mkdir(parents=True, exist_ok=True)


def open_fixture(page):
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(f"{URL}/?theme=light&scale=1", wait_until="load")
    page.wait_for_timeout(4_000)
    return errors


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        headless=True,
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    context = browser.new_context(
        viewport={"width": 320, "height": 640},
        device_scale_factor=1,
        reduced_motion="reduce",
    )
    page = context.new_page()
    errors = open_fixture(page)
    screenshot = OUTPUT / "math-keyboard-zh-cn-320x640-scale1-light.png"
    page.screenshot(path=str(screenshot))
    rendered = Image.open(screenshot).convert("RGB")
    if rendered.getbbox() is None or max(ImageStat.Stat(rendered).stddev) < 1:
        raise RuntimeError("Flutter Web produced a blank screenshot")
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
    browser.close()


with tempfile.TemporaryDirectory(prefix="stroom-math-keyboard-") as frame_dir:
    frames = Path(frame_dir)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        context = browser.new_context(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
            reduced_motion="no-preference",
        )
        page = context.new_page()
        errors = open_fixture(page)
        for frame in range(36):
            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
            page.wait_for_timeout(250)
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
        browser.close()
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-framerate",
            "4",
            "-i",
            str(frames / "frame-%03d.png"),
            "-c:v",
            "libvpx-vp9",
            "-b:v",
            "1M",
            "-pix_fmt",
            "yuv420p",
            str(OUTPUT / "math-keyboard-label-reveal-320x640.webm"),
        ],
        check=True,
    )

print(
    {
        "viewport_css_px": {"width": 320, "height": 640},
        "device_pixel_ratio": 1,
        "locale": "zh-CN",
        "theme": "light",
        "text_scale": 1,
        "focus": "none",
        "software_keyboard": "closed",
        "screenshot_reduced_motion": "reduce",
        "preview_reduced_motion": "no-preference",
        "fixture_data": "local math expression and long active formula/location labels; no network or account data",
        "motion_preview_frames": 36,
    }
)
