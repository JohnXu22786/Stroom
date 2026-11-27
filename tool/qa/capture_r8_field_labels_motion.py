from pathlib import Path
import subprocess
import tempfile
import time

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/r8-field-labels/after"
BASE_URL = "http://127.0.0.1:8878/"

scenes = [
    ("language-search-de-320x640-scale2", "theme", 320, 640, 2, None, "theme", 11.8),
    (
        "folder-file-name-de-360x800-scale2",
        "folder",
        360,
        800,
        2,
        None,
        "folder-file-name",
        57.4,
    ),
    (
        "folder-folder-name-de-360x800-scale2",
        "folder",
        360,
        800,
        2,
        "folder-name",
        "folder-name",
        24.3,
    ),
]
fps = 3.4

with tempfile.TemporaryDirectory(prefix="r8-field-labels-motion-") as temp_dir:
    temp = Path(temp_dir)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        for filename, scene, width, height, scale, hint_mode, action, duration in scenes:
            frame_dir = temp / filename
            frame_dir.mkdir()
            page = browser.new_page(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
            )
            page.emulate_media(reduced_motion="reduce")
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            hint_query = f"&hintMode={hint_mode}" if hint_mode else ""
            page.goto(
                f"{BASE_URL}?scene={scene}&locale=de-DE&scale={scale}{hint_query}",
                wait_until="load",
                timeout=120_000,
            )
            page.locator("flt-semantics-placeholder").evaluate(
                "element => element.click()"
            )
            page.wait_for_timeout(1_500)
            if action == "theme":
                page.get_by_role("textbox").first.scroll_into_view_if_needed()
            elif action == "folder-name":
                page.get_by_role("button", name="Neuen Ordner erstellen").click()
            started = time.monotonic()
            initial_frames = 4
            for frame in range(initial_frames):
                page.screenshot(path=str(frame_dir / f"frame_{frame:03d}.png"))
            page.emulate_media(reduced_motion="no-preference")
            frame_count = round(duration * fps)
            for frame in range(frame_count - initial_frames):
                page.wait_for_timeout(250 if action == "theme" else 245)
                frame += initial_frames
                if frame >= frame_count - 3:
                    page.emulate_media(reduced_motion="reduce")
                page.screenshot(path=str(frame_dir / f"frame_{frame:03d}.png"))
            recording_seconds = round(time.monotonic() - started, 1)
            if errors:
                raise RuntimeError(f"Browser errors in {filename}: {errors}")
            page.close()
            output = OUTPUT / f"{filename}.webm"
            subprocess.run(
                [
                    "/usr/bin/ffmpeg",
                    "-y",
                    "-loglevel",
                    "error",
                    "-framerate",
                    str(fps),
                    "-i",
                    str(frame_dir / "frame_%03d.png"),
                    "-c:v",
                    "libvpx-vp9",
                    "-pix_fmt",
                    "yuv420p",
                    str(output),
                ],
                check=True,
            )
            print(
                {
                    "video": str(output),
                    "target_seconds": duration,
                    "recording_seconds": recording_seconds,
                    "page_errors": errors,
                }
            )
        browser.close()
