# OCR batch mode responsive captures

These screenshots render the production `OcrPage` with two in-memory PNG fixtures, German (`de-DE`) localization, Material 3 light theme, and no provider request. The narrow capture is 320 × 640 CSS pixels at 1× text scale; the large-text capture is 600 × 1000 at 2×. The compact layout stacks the complete batch label and radio options. At a fitting width, the existing inline segmented control remains in one row.

- [Narrow viewport, 1×](ocr-batch-de-320x640-1x-light.png)
- [Large text, 2×](ocr-batch-de-600x1000-2x-light.png)
- [Capture entrypoint](../../../tool/qa/ocr_batch_mode_capture.dart)
- [Capture script](../../../tool/qa/capture_ocr_batch_mode.py)

The browser reported no page errors. Focused widget coverage checks German at 320 × 640 / 1×, German at 600 × 1000 / 2×, the per-image concurrency control at 600 × 1000 / 1×, Chinese at 700 × 1000 / 1× and 367 × 1000 / 1× plus 580 × 1000 and 568 × 1000 / 2× where the inline controls fit, and English at 1250 × 1000 / 2× where the longer segment label requires the compact layout:

```sh
flutter test --no-pub --reporter expanded --plain-name 'reflows batch options at narrow width and large localized text' tests/pages/content/ocr_page_test.dart
```

Regenerate the release captures with:

```sh
flutter build web --release --no-pub --target tool/qa/ocr_batch_mode_capture.dart --output /tmp/stroom-ocr-batch-mode-web --no-wasm-dry-run
python3 tool/qa/capture_ocr_batch_mode.py
```
