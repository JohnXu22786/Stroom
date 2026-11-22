# OCR selector layout at narrow width

The screenshot is a release Flutter Web capture of the production `OcrPage` at 320 × 640 CSS pixels, device scale factor 1, German (`de-DE`), Material 3 light theme, and normal 1× text scale. The in-memory fixture selects a long model value and a long saved instruction to show both controls in the compact layout. No control is focused, the desktop browser keyboard is closed, reduced motion is enabled for a stable still, and no provider request or account data is used.

The fixture uses a temporary entrypoint that is removed after capture. Chromium reported no page errors.

- [Production OCR selector screenshot](ocr-selectors-de-320x640-1x-light.png)
- Focused test: `flutter test --no-pub --reporter expanded --plain-name 'reflows selectors at narrow width and large text scale in LTR and RTL' tests/pages/content/ocr_page_test.dart`
