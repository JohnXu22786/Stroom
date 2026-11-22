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
`.test` URL and its token is fake local QA text. Chromium routing aborted every
request outside the local capture server before network access; the captured
run blocked 45 font requests to `fonts.gstatic.com` and reported no page errors.
No URL was opened or submitted.

The capture harness rendered the repository's production widget directly in a
small Flutter app shell, using `flutter build web --release` with local
CanvasKit. The host has no CJK system font, so the panel's fixed Chinese chrome
labels appear as fallback boxes; the URL itself uses Chromium's normal Latin
font at the app's regular size. The capture verifies the real component layout
and URL reveal, rather than a mock or a test-font rendering.
