from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
from threading import Thread

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/qa/connectivity_test_tool_names"
OUTPUT.mkdir(parents=True, exist_ok=True)


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


with tempfile.TemporaryDirectory(prefix="stroom-connectivity-capture-") as build_dir:
    web_root = Path(build_dir) / "web"
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-pub",
            "--target",
            "tool/qa/connectivity_test_dialog_capture.dart",
            "--output",
            str(web_root),
            "--no-wasm-dry-run",
        ],
        cwd=ROOT,
        check=True,
    )

    server = ThreadingHTTPServer(
        ("127.0.0.1", 0),
        lambda *args, **kwargs: QuietHandler(
            *args, directory=str(web_root), **kwargs
        ),
    )
    Thread(target=server.serve_forever, daemon=True).start()

    errors = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                headless=True,
                executable_path="/usr/bin/chromium",
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            context = browser.new_context(
                viewport={"width": 320, "height": 640},
                device_scale_factor=1,
                locale="de-DE",
                color_scheme="light",
                reduced_motion="no-preference",
            )
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"http://127.0.0.1:{server.server_port}",
                wait_until="load",
                timeout=120_000,
            )
            placeholder = page.locator("flt-semantics-placeholder")
            placeholder.wait_for(timeout=120_000)
            placeholder.focus()
            placeholder.press("Enter")
            page.wait_for_function(
                "() => document.body.innerText.includes('MCP tools/list') "
                "&& document.body.innerText.includes('Lokaler Vorschauwert')",
                timeout=120_000,
            )
            page.wait_for_timeout(250)
            page.mouse.move(160, 420)
            page.mouse.wheel(0, 700)
            page.wait_for_timeout(250)
            page.screenshot(
                path=str(OUTPUT / "mcp-tool-names-de-320x640-1x-light.png")
            )
            context.close()
            browser.close()
    finally:
        server.shutdown()
        server.server_close()

if errors:
    raise RuntimeError(f"Browser reported page errors: {errors}")

print(
    {
        "viewport_css_px": {"width": 320, "height": 640},
        "device_pixel_ratio": 1,
        "locale": "de-DE",
        "theme": "blue-seeded light",
        "text_scale": 1,
        "focus": "JSON field focused by the dialog preview; no action activated",
        "keyboard": "none",
        "network_or_account_data": "none; dedicated local fixture build only",
        "page_errors": errors,
    }
)
