# Detected resource URL reveal capture

These files record the production `DraggableFloatingPanel` in a real Chromium
Flutter Web release build at a 320 × 640 CSS-pixel viewport and device scale
factor 1. The panel uses the normal application text scale (1.0), an `en-US`
locale, and a light Material 3 theme seeded with blue. No element is focused,
the keyboard is closed, and the preview starts with the panel already visible.

- [Initial screenshot](resource-url-top-320x640-1x-en-light.png)
- [Screenshot at the revealed endpoint](resource-url-bottom-320x640-1x-en-light.png)
- [14-second playable vertical reveal](resource-url-vertical-reveal-320x640-1x-light.webm)

The preview includes the component's initial still period (about one second),
then the real `ConstrainedText` vertical scroll through to a stable endpoint.
The endpoint screenshot shows the URL's final path and query text, while the
initial screenshot shows its beginning. The sample is a synthetic reserved
`.test` URL and its token is fake local QA text. No URL was opened or submitted.

The capture harness rendered the repository's production widget directly in a
small Flutter app shell, using `flutter build web --release` with local
CanvasKit. The host's installed Noto Sans CJK SC regular font was subset to the
panel's Chinese glyphs and loaded as a temporary Flutter font fallback for
this capture. The app's normal primary font remains in use for Latin URL text;
the production font size and labels are unchanged. The font subset and capture
harness are not production assets. Chromium made no external requests and
reported no page errors.
