from pathlib import Path
import subprocess
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/media-picker-error"
SCREENSHOT = OUTPUT / "media-picker-error-fr-320x640-scale1-light.png"
PORT = 8879
URL = f"http://127.0.0.1:{PORT}/?locale=fr"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
        "tools/qa/app_media_picker_error_capture.dart",
    ],
    cwd=ROOT,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.STDOUT,
)

try:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError(f"Flutter web server exited with {server.returncode}")
        try:
            with urlopen(f"http://127.0.0.1:{PORT}/", timeout=1):
                break
        except Exception:
            time.sleep(1)
    else:
        raise TimeoutError("Flutter web server did not become ready")

    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        page = browser.new_page(
            viewport={"width": 320, "height": 640}, device_scale_factor=1
        )
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(URL, wait_until="load", timeout=120_000)
        page.wait_for_timeout(2_000)
        if page.locator("flt-semantics-placeholder").count():
            page.locator("flt-semantics-placeholder").evaluate(
                "element => element.click()"
            )
            page.get_by_role("button", name="Open picker").click(timeout=30_000)
        else:
            page.mouse.click(160, 320)
        retry = page.get_by_role("button", name="Réessayer")
        retry.wait_for(timeout=30_000)
        page.mouse.move(160, 500)
        page.mouse.wheel(0, 12_000)
        page.wait_for_timeout(300)
        if page.evaluate("devicePixelRatio") != 1:
            raise RuntimeError("Capture device pixel ratio was not 1")
        page.screenshot(path=str(SCREENSHOT))
        print(
            {
                "screenshot": str(SCREENSHOT.relative_to(ROOT)),
                "viewport_css_px": {"width": 320, "height": 640},
                "device_pixel_ratio": 1,
                "locale": "fr_FR",
                "theme": "light Material 3",
                "focus": "none",
                "keyboard": "closed",
                "fixture": "local diagnostic only; no account data or network request",
                "page_errors": errors,
            }
        )
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
