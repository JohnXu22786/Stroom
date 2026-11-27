from pathlib import Path
import subprocess
import tempfile
import time

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/r8-field-labels/after"
BASE_URL = "http://127.0.0.1:8878/"

scenes = [
    ("language-search-de-320x640-scale2", "theme", 320, 640, 2, "theme"),
    ("folder-hints-de-360x800-scale2", "folder", 360, 800, 2, "folder"),
]

with tempfile.TemporaryDirectory(prefix="r8-field-labels-motion-") as temp_dir:
    temp = Path(temp_dir)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        for filename, scene, width, height, scale, action in scenes:
            frame_dir = temp / filename
            frame_dir.mkdir()
            page = browser.new_page(
                viewport={"width": width, "height": height},
                device_scale_factor=1,
            )
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{BASE_URL}?scene={scene}&locale=de-DE&scale={scale}",
                wait_until="load",
                timeout=120_000,
            )
            page.locator("flt-semantics-placeholder").evaluate(
                "element => element.click()"
            )
            page.wait_for_timeout(1_500)
            if action == "theme":
                page.get_by_role("textbox").first.scroll_into_view_if_needed()
            else:
                page.get_by_role("button", name="Neuen Ordner erstellen").click()
            page.wait_for_timeout(1_500)
            started = time.monotonic()
            for frame in range(36):
                page.wait_for_timeout(250)
                page.screenshot(path=str(frame_dir / f"frame_{frame:03d}.png"))
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
                    "4",
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
                    "recorded_seconds": round(time.monotonic() - started, 1),
                    "page_errors": errors,
                }
            )
        browser.close()
