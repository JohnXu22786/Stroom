from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/ui-constrained-text-qa/vertical-chat-edit-warning"
SCREENSHOT = OUTPUT / "chat-page-edit-warning-fr-320x640-scale1.5-keyboard.png"
URL = "http://127.0.0.1:8880/"
OUTPUT.mkdir(parents=True, exist_ok=True)

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
    errors = []
    stage = ["initial load"]
    page.on("pageerror", lambda error: errors.append(f"{stage[0]}: {error}: {error.stack}"))
    page.goto(URL, wait_until="load", timeout=120_000)
    page.wait_for_timeout(8_000)
    stage[0] = "enable semantics"
    page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
    stage[0] = "reveal earlier message action"
    page.mouse.move(160, 160)
    page.mouse.wheel(0, -500)
    page.wait_for_timeout(400)
    stage[0] = "enter edit mode on earlier message"
    page.get_by_role("button", name="Modifier", exact=True).first.click(
        timeout=5_000
    )
    page.wait_for_timeout(500)
    warning = page.get_by_text(
        "Tous les messages suivants seront supprimés lorsque vous modifierez et renverrez ce message",
        exact=True,
    )
    warning_box = warning.bounding_box()
    if not warning_box or warning_box["y"] < 0 or warning_box["y"] + warning_box["height"] > 380:
        raise RuntimeError(f"The full warning is outside the keyboard-safe page area: {warning_box}")

    screenshot = page.screenshot()
    if page.evaluate("devicePixelRatio") != 1:
        raise RuntimeError("Capture device pixel ratio was not 1")
    SCREENSHOT.write_bytes(screenshot)
    unexpected_errors = [
        error for error in errors if "Cache disposed during open" not in error
    ]
    if unexpected_errors:
        raise RuntimeError(f"Browser reported runtime errors: {unexpected_errors}")
    print(
        {
            "page_scroll_y": page.evaluate("window.scrollY"),
            "warning_box": warning_box,
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
            "viewport_css_px": {"width": 320, "height": 640},
            "device_pixel_ratio": 1,
            "locale": "fr-FR",
            "theme": "Material 3 light, blue-seeded fallback",
            "text_scale": 1.5,
            "focus": "edit field focused",
            "keyboard": "260dp reserved viewport inset (Flutter Web keyboard simulation; browser does not draw native keyboard)",
            "fixture": "production ChatPage with in-memory messages and dummy provider; no account or network request",
            "page_errors": errors,
            "known_fixture_runtime_error": "flutter_chat_ui IndexedDB CrossCache disposal race during initial load; screenshot itself is captured after editing and remains readable",
        }
    )
    browser.close()
