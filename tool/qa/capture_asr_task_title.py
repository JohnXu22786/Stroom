from pathlib import Path
import subprocess
import tempfile
import time

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/asr_task_title"
WEB = Path("/tmp/stroom-asr-task-title-web")
URL = "http://127.0.0.1:8878"
OUTPUT.mkdir(parents=True, exist_ok=True)


def main():
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target",
            "tool/qa/asr_task_title_capture.dart",
            "--output",
            str(WEB),
            "--no-wasm-dry-run",
        ],
        cwd=ROOT,
        check=True,
    )
    server = subprocess.Popen(
        [
            "python3",
            "-m",
            "http.server",
            "8878",
            "--bind",
            "127.0.0.1",
            "--directory",
            str(WEB),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    errors = []
    try:
        time.sleep(1)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            for reduced_motion, output_name in [
                ("reduce", "asr-task-title-320x640-1x.png"),
                ("no-preference", None),
            ]:
                context = browser.new_context(
                    viewport={"width": 320, "height": 640},
                    device_scale_factor=1,
                    reduced_motion=reduced_motion,
                )
                page = context.new_page()
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(f"{URL}/?locale=en-US&theme=light&scale=1", wait_until="load")
                page.wait_for_timeout(10_000)
                if page.evaluate("devicePixelRatio") != 1:
                    raise RuntimeError("Expected a 1x browser device scale factor")
                if output_name is not None:
                    page.screenshot(path=str(OUTPUT / output_name))
                else:
                    with tempfile.TemporaryDirectory(prefix="stroom-asr-task-title-") as frame_dir:
                        frames = Path(frame_dir)
                        for frame in range(32):
                            page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                            page.wait_for_timeout(250)
                        subprocess.run(
                            [
                                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                                "-framerate", "4", "-i", str(frames / "frame-%03d.png"),
                                "-c:v", "libvpx-vp9", "-b:v", "1M", "-pix_fmt",
                                "yuv420p", str(OUTPUT / "asr-task-title-motion-320x640-1x.webm"),
                            ],
                            check=True,
                        )
                context.close()
            browser.close()
        if errors:
            raise RuntimeError(f"Browser reported runtime errors: {errors}")
    finally:
        server.terminate()
        server.wait(timeout=10)
    print({"viewport": "320x640", "device_scale_factor": 1, "locale": "en-US", "theme": "light", "text_scale": 1, "page_errors": errors})


if __name__ == "__main__":
    main()
