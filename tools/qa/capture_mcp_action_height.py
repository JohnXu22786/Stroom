from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[2]
STATE = Path("/workspace/.cloud-profile-state/round11-mcp-action-height")
WEB_BUILD = STATE / "web-build"
OUTPUT = ROOT / "docs/ui-constrained-text-qa/round11-mcp-action-height"
OUTPUT.mkdir(parents=True, exist_ok=True)

subprocess.run(
    [
        "flutter",
        "build",
        "web",
        "--release",
        "--no-pub",
        "--target=tool/qa/mcp_action_height_capture.dart",
        f"--output={WEB_BUILD}",
        "--no-wasm-dry-run",
    ],
    cwd=ROOT,
    check=True,
)

with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    port = listener.getsockname()[1]

server = subprocess.Popen(
    [
        sys.executable,
        "-m",
        "http.server",
        str(port),
        "--bind",
        "127.0.0.1",
        "--directory",
        str(WEB_BUILD),
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

try:
    base_url = f"http://127.0.0.1:{port}/"
    for _ in range(100):
        if server.poll() is not None:
            raise RuntimeError("Local Flutter Web server exited before becoming ready")
        try:
            with urlopen(base_url, timeout=1):
                break
        except Exception:
            time.sleep(0.1)
    else:
        raise RuntimeError("Local Flutter Web server did not become ready")

    cases = [
        {
            "name": "mcp-actions-fr-320x320-scale4-light-discard.png",
            "width": 320,
            "height": 320,
            "locale": "fr-FR",
            "scale": 4,
            "theme": "light",
            "save_label": "Enregistrer",
            "discard_label": "Abandonner",
            "scroll_for_discard": 160,
            "top_screenshot": "mcp-actions-fr-320x320-scale4-light-save.png",
        },
        {
            "name": "mcp-actions-fr-320x640-scale4-light.png",
            "width": 320,
            "height": 640,
            "locale": "fr-FR",
            "scale": 4,
            "theme": "light",
            "save_label": "Enregistrer",
            "discard_label": "Abandonner",
        },
        {
            "name": "mcp-actions-en-240x640-scale1-light.png",
            "width": 240,
            "height": 640,
            "locale": "en-US",
            "scale": 1,
            "theme": "light",
            "save_label": "Save",
            "discard_label": "Discard",
        },
        {
            "name": "mcp-actions-fr-320x640-scale4-dark.png",
            "width": 320,
            "height": 640,
            "locale": "fr-FR",
            "scale": 4,
            "theme": "dark",
            "save_label": "Enregistrer",
            "discard_label": "Abandonner",
        },
    ]
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path="/usr/bin/chromium",
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )
        for case in cases:
            page = browser.new_page(
                viewport={"width": case["width"], "height": case["height"]},
                device_scale_factor=1,
                reduced_motion="reduce",
            )
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(
                f"{base_url}?locale={case['locale']}&scale={case['scale']}&theme={case['theme']}",
                wait_until="load",
                timeout=120_000,
            )
            page.locator("canvas").wait_for(state="visible", timeout=30_000)
            page.wait_for_timeout(1_000)
            page.mouse.click(case["width"] / 2, case["height"] / 2)
            page.wait_for_timeout(1_000)
            page.locator("flt-semantics-placeholder").evaluate(
                '(element) => element.dispatchEvent(new MouseEvent("click", {bubbles: true}))'
            )
            action_bounds = {}
            for action, label in [
                ("save", case["save_label"]),
                ("discard", case["discard_label"]),
            ]:
                if action == "discard" and case.get("scroll_for_discard"):
                    page.mouse.move(case["width"] / 2, case["height"] / 2)
                    page.mouse.wheel(0, case["scroll_for_discard"])
                    page.wait_for_timeout(500)
                button = page.get_by_role("button", name=label)
                button.wait_for(state="visible", timeout=10_000)
                bounds = button.bounding_box()
                if bounds is None:
                    raise RuntimeError(f"MCP {action} action is not visible: {label}")
                if (
                    bounds["x"] < 0
                    or bounds["y"] < 0
                    or bounds["x"] + bounds["width"] > case["width"]
                    or bounds["y"] + bounds["height"] > case["height"]
                ):
                    raise RuntimeError(f"MCP {action} action is outside the viewport: {bounds}")
                action_bounds[action] = bounds
                if action == "save" and case.get("top_screenshot"):
                    top_path = OUTPUT / case["top_screenshot"]
                    top_path.write_bytes(page.screenshot())
                    print(
                        {
                            "screenshot": str(top_path.relative_to(ROOT)),
                            "viewport_logical_px": {
                                "width": case["width"],
                                "height": case["height"],
                            },
                            "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                            "locale": case["locale"],
                            "text_scale": case["scale"],
                            "theme": f"{case['theme']} Material 3",
                            "state": "new MCP server configuration dialog with Save row visible",
                            "action_bounds_logical_px": {"save": bounds},
                            "page_errors": errors,
                        }
                    )
            screenshot = page.screenshot()
            output_path = OUTPUT / case["name"]
            output_path.write_bytes(screenshot)
            print(
                {
                    "screenshot": str(output_path.relative_to(ROOT)),
                    "viewport_logical_px": {
                        "width": case["width"],
                        "height": case["height"],
                    },
                    "device_pixel_ratio": page.evaluate("devicePixelRatio"),
                    "locale": case["locale"],
                    "text_scale": case["scale"],
                    "theme": f"{case['theme']} Material 3",
                    "state": "new MCP server configuration dialog",
                    "action_bounds_logical_px": action_bounds,
                    "page_errors": errors,
                }
            )
            page.close()
        browser.close()
    if errors:
        raise RuntimeError(f"Browser reported runtime errors: {errors}")
finally:
    server.terminate()
    server.wait(timeout=5)
