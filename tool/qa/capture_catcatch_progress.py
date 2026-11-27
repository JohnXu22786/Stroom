from pathlib import Path
import socket
import subprocess
import tempfile
from contextlib import closing
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

from PIL import Image
from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/catcatch-progress-percentage"
OUTPUT.mkdir(parents=True, exist_ok=True)

class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format, *_args):
        pass


with tempfile.TemporaryDirectory(
    prefix="stroom-catcatch-progress-web-"
) as web_build_dir:
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target=tool/qa/catcatch_progress_capture.dart",
            f"--output-dir={web_build_dir}",
        ],
        cwd=ROOT,
        check=True,
    )

    with closing(socket.socket()) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    server = ThreadingHTTPServer(
        ("127.0.0.1", port),
        lambda *args, **kwargs: QuietHandler(
            *args, directory=web_build_dir, **kwargs
        ),
    )
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            captures = []
            for scale in (1, 3):
                for theme in ("light", "dark"):
                    context = browser.new_context(
                        viewport={"width": 320, "height": 640},
                        device_scale_factor=scale,
                        reduced_motion="reduce",
                    )
                    page = context.new_page()
                    page_errors = []
                    page.on("pageerror", lambda error: page_errors.append(str(error)))
                    page.goto(
                        f"http://127.0.0.1:{port}/?scale={scale}&theme={theme}",
                        wait_until="load",
                    )
                    page.wait_for_timeout(12_000)
                    path = OUTPUT / (
                        f"catcatch-progress-100-320x640-scale{scale}-{theme}.png"
                    )
                    page.screenshot(path=str(path))
                    image = Image.open(path).convert("RGB")
                    card_crop = image.crop((0, 0, image.width, min(image.height, 200 * scale)))
                    color_count = len(set(card_crop.getdata()))
                    if color_count < 10:
                        raise RuntimeError(
                            f"Flutter Web screenshot has no visible card: {path} "
                            f"({color_count} colors in the top card area)"
                        )
                    if page_errors:
                        raise RuntimeError(f"Browser reported page errors: {page_errors}")
                    captures.append(
                        {
                            "path": str(path.relative_to(ROOT)),
                            "viewport_css_px": page.viewport_size,
                            "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                            "text_scale": scale,
                            "theme": theme,
                            "progress": "100%",
                            "top_card_area_color_count": color_count,
                            "page_errors": page_errors,
                        }
                    )
                    context.close()
            browser.close()
            print(captures)
    finally:
        server.shutdown()
        server.server_close()
        server_thread.join(timeout=5)
