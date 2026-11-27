from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

from capture_managed_outputs import RESPONSIVE_MEDIA_OUTPUT_PATTERNS, CaptureOutputs


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/responsive-media-layout"
PORT = 8894
BASE_URL = f"http://127.0.0.1:{PORT}/"
SERVER_LOG = Path("/tmp/r8-responsive-media-layout-flutter.log")
OUTPUT.mkdir(parents=True, exist_ok=True)
captures = CaptureOutputs(OUTPUT, RESPONSIVE_MEDIA_OUTPUT_PATTERNS)
captures.clear()


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        screenshot = page.screenshot()
        image = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(image).stddev) >= 1:
            return
        page.wait_for_timeout(1_000)
    raise TimeoutError("Flutter Web remained blank after page load")

server_log = SERVER_LOG.open("w")
server = subprocess.Popen(
    [
        "flutter",
        "run",
        "-d",
        "web-server",
        "--web-hostname",
        "127.0.0.1",
        "--web-port",
        str(PORT),
        "--target",
        "tools/qa/responsive_media_layout_capture.dart",
    ],
    cwd=ROOT,
    stdout=server_log,
    stderr=subprocess.STDOUT,
)

try:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(
                f"Flutter web server exited with {server.returncode}: "
                f"{SERVER_LOG.read_text()[-3000:]}"
            )
        if "responsive_media_layout_capture.dart is being served at" in (
            SERVER_LOG.read_text()
        ):
            break
        time.sleep(1)
    else:
        raise TimeoutError(
            f"Flutter web server did not finish startup: {SERVER_LOG.read_text()[-3000:]}"
        )

    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 320, "height": 640},
            device_scale_factor=1,
        )
        page.on("pageerror", lambda error: errors.append(str(error)))

        for scale in (1, 3):
            if scale == 3:
                page.emulate_media(reduced_motion="reduce")
            static_mode = "&static=1" if scale == 3 else ""
            page.goto(
                f"{BASE_URL}?component=picker&scale={scale}{static_mode}",
                wait_until="load",
            )
            wait_for_rendered_flutter(page)
            # Flutter Web's semantics tree does not expose Text labels in this
            # isolated canvas fixture, so use the visible production controls.
            page.mouse.click(160, 320)
            page.wait_for_timeout(500)
            page.mouse.click(160, 95)
            if scale == 3:
                page.wait_for_timeout(15_000)
            else:
                page.wait_for_timeout(500)
            screenshot = page.screenshot()
            image = Image.open(BytesIO(screenshot)).convert("RGB")
            filename = f"media-picker-fr-320x640-scale{scale}-light.png"
            captures.write(filename, screenshot)
            if image.size != (320, 640) or max(ImageStat.Stat(image).stddev) < 1:
                raise RuntimeError(
                    f"Unexpected media picker capture: {image.size}, "
                    f"standard deviation {ImageStat.Stat(image).stddev}"
                )
            if scale == 3:
                # The static screenshot shows stable ellipsis. The playable
                # recording switches motion back on and spans the initial
                # pause, a complete reveal, endpoint pause, and reverse pass.
                page.emulate_media(reduced_motion="no-preference")
                page.goto(
                    f"{BASE_URL}?component=picker&scale=3", wait_until="load"
                )
                wait_for_rendered_flutter(page)
                page.mouse.click(160, 320)
                page.wait_for_timeout(500)
                page.mouse.click(160, 95)
                # Begin immediately at 1×, before the harness timer changes
                # the selected picker to 3×. This includes the stationary
                # first second after the labels first become clipped.
                frames_per_second = 8
                duration_seconds = 32
                with tempfile.TemporaryDirectory(
                    prefix="r8-media-picker-reveal-"
                ) as frame_dir:
                    frame_path = Path(frame_dir) / "frame-%03d.png"
                    started = time.monotonic()
                    for index in range(frames_per_second * duration_seconds):
                        page.screenshot(
                            path=str(Path(frame_dir) / f"frame-{index:03d}.png")
                        )
                        target = started + (index + 1) / frames_per_second
                        delay = target - time.monotonic()
                        if delay > 0:
                            time.sleep(delay)
                    subprocess.run(
                        [
                            "ffmpeg",
                            "-y",
                            "-framerate",
                            str(frames_per_second),
                            "-i",
                            str(frame_path),
                            "-c:v",
                            "libvpx-vp9",
                            "-pix_fmt",
                            "yuv420p",
                            "-b:v",
                            "500k",
                            str(OUTPUT / "media-picker-fr-320x640-scale3-reveal.webm"),
                        ],
                        check=True,
                        stdout=subprocess.DEVNULL,
                    )
                    captures.record("media-picker-fr-320x640-scale3-reveal.webm")

        for scale in (1, 3):
            page.goto(f"{BASE_URL}?component=mermaid&scale={scale}", wait_until="load")
            wait_for_rendered_flutter(page)
            if page.locator("flt-semantics-placeholder").count():
                page.locator("flt-semantics-placeholder").evaluate(
                    "element => element.click()"
                )
            page.wait_for_timeout(500)
            image = Image.open(BytesIO(page.screenshot())).convert("RGB")
            if image.size != (320, 640) or max(ImageStat.Stat(image).stddev) < 1:
                raise RuntimeError(f"Unexpected Mermaid capture: {image.size}")
            filename = f"mermaid-loading-fr-320x640-scale{scale}-light.png"
            captures.write(filename, page.screenshot())

        print(
            {
                "files": captures.names,
                "viewport_css_px": {"width": 320, "height": 640},
                "device_pixel_ratio": 1,
                "locale": "fr_FR",
                "theme": "light Material 3",
                "text_scales": [1, 3],
                "fixtures": "production picker dialog and production streaming Mermaid pre-builder",
                "network": "none",
                "page_errors": errors,
            }
        )
        page.close()
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    server_log.close()
