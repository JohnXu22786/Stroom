from io import BytesIO
from pathlib import Path
import subprocess
import time
from urllib.request import urlopen

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/compact-rows"
PORT = 8895
URL = f"http://127.0.0.1:{PORT}/"
SERVER_LOG = OUTPUT / ".flutter-web.log"
OUTPUT.mkdir(parents=True, exist_ok=True)
server_log = SERVER_LOG.open("w")
server = subprocess.Popen(
    [
        "flutter",
        "run",
        "--release",
        "--no-pub",
        "-d",
        "web-server",
        "--web-hostname",
        "127.0.0.1",
        "--web-port",
        str(PORT),
        "--target",
        "tools/qa/compact_row_voice_index_capture.dart",
    ],
    cwd=ROOT,
    stdout=server_log,
    stderr=subprocess.STDOUT,
)


def wait_for_rendered_flutter(page):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        screenshot = page.screenshot()
        rendered = Image.open(BytesIO(screenshot)).convert("RGB")
        if max(ImageStat.Stat(rendered).stddev) > 1:
            return
        page.wait_for_timeout(500)
    raise TimeoutError("Flutter Web did not render the production voice fixture")


try:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(
                f"Flutter web server exited with {server.returncode}: {SERVER_LOG.read_text()}"
            )
        try:
            with urlopen(URL, timeout=1):
                if "is being served at" in SERVER_LOG.read_text():
                    break
        except Exception:
            time.sleep(1)
    else:
        raise TimeoutError(f"Flutter web server not ready: {SERVER_LOG.read_text()}")

    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 600, "height": 640},
            device_scale_factor=1,
            reduced_motion="reduce",
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        for theme in ("light", "dark"):
            page.set_viewport_size({"width": 600, "height": 640})
            page.goto(
                f"{URL}?locale=fr&scale=1&count=1&theme={theme}",
                wait_until="load",
                timeout=120_000,
            )
            wait_for_rendered_flutter(page)
            page.wait_for_timeout(300)
            suffix = "-dark" if theme == "dark" else ""
            (OUTPUT / f"voice-index-fitting-1x{suffix}.png").write_bytes(
                page.screenshot()
            )

            page.set_viewport_size({"width": 1000, "height": 1200})
            page.goto(
                f"{URL}?locale=fr&scale=2&count=1234&theme={theme}",
                wait_until="load",
                timeout=120_000,
            )
            wait_for_rendered_flutter(page)
            page.wait_for_timeout(300)
            page.mouse.move(500, 600)
            page.mouse.wheel(0, 2_000_000)
            page.wait_for_timeout(1000)
            page.mouse.move(0, 0)
            (OUTPUT / f"voice-index-scaled-high-count-2x{suffix}.png").write_bytes(
                page.screenshot()
            )

            page.set_viewport_size({"width": 440, "height": 932})
            page.goto(
                f"{URL}?locale=fr&scale=2&count=1234&theme={theme}",
                wait_until="load",
                timeout=120_000,
            )
            wait_for_rendered_flutter(page)
            page.wait_for_timeout(300)
            page.mouse.move(220, 460)
            page.mouse.wheel(0, 2_000_000)
            page.wait_for_timeout(1000)
            page.mouse.move(0, 0)
            (OUTPUT / f"voice-index-scaled-narrow-2x{suffix}.png").write_bytes(
                page.screenshot()
            )

            page.set_viewport_size({"width": 320, "height": 932})
            page.goto(
                f"{URL}?locale=ar&scale=2&count=1&theme={theme}",
                wait_until="load",
                timeout=120_000,
            )
            wait_for_rendered_flutter(page)
            page.wait_for_timeout(300)
            page.mouse.move(0, 0)
            (OUTPUT / f"voice-index-rtl-narrow-2x{suffix}.png").write_bytes(
                page.screenshot()
            )
        browser.close()

    if errors:
        raise RuntimeError(f"Browser errors: {errors}")
finally:
    server.terminate()
    server.wait(timeout=10)
    server_log.close()
    SERVER_LOG.unlink(missing_ok=True)

print("Captured French voice duplicate resolution at fitting, wide, and narrow scales, plus narrow Arabic RTL, in light and dark themes.")
