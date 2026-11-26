from pathlib import Path
import subprocess
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/jumping_dots_scaling"
OUTPUT.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="stroom-jumping-dots-web-") as build_dir:
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target",
            "tool/qa/jumping_dots_scaling_capture.dart",
            "--output",
            build_dir,
            "--no-wasm-dry-run",
        ],
        cwd=ROOT,
        check=True,
    )

    class QuietHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=build_dir, **kwargs)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), QuietHandler)
    Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}"
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            context = browser.new_context(
                viewport={"width": 360, "height": 280},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            page = context.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(f"{url}/?motion=false", wait_until="load")
            page.wait_for_timeout(12_000)
            screenshot = OUTPUT / "jumping-dots-1x-and-2x.png"
            page.screenshot(path=str(screenshot))
            if Image.open(screenshot).convert("RGB").getbbox() is None:
                raise RuntimeError("Flutter Web produced a blank screenshot")
            if errors:
                raise RuntimeError(f"Browser reported runtime errors: {errors}")
            browser.close()

        with tempfile.TemporaryDirectory(prefix="stroom-jumping-dots-frames-") as frame_dir:
            frames = Path(frame_dir)
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(
                    headless=True,
                    executable_path="/usr/bin/chromium",
                    args=["--no-sandbox", "--disable-dev-shm-usage"],
                )
                context = browser.new_context(
                    viewport={"width": 360, "height": 280},
                    device_scale_factor=1,
                    reduced_motion="no-preference",
                )
                page = context.new_page()
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(f"{url}/?motion=true", wait_until="load")
                page.wait_for_timeout(12_000)
                for frame in range(48):
                    page.screenshot(path=str(frames / f"frame-{frame:03d}.png"))
                    page.wait_for_timeout(125)
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
                    "8",
                    "-i",
                    str(frames / "frame-%03d.png"),
                    "-c:v",
                    "libvpx-vp9",
                    "-b:v",
                    "1M",
                    "-pix_fmt",
                    "yuv420p",
                    str(OUTPUT / "jumping-dots-motion.webm"),
                ],
                check=True,
            )
    finally:
        server.shutdown()

print(
    {
        "viewport_css_px": {"width": 360, "height": 280},
        "device_pixel_ratio": 1,
        "text_scales": [1, 2],
        "preview_frames": 48,
        "page_errors": [],
    }
)
