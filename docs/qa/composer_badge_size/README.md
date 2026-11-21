# Composer badge size QA

These screenshots show the production `SettingsChip` with its normal English label and active badge count. The one digit badge remains circular; two digit and `99+` counts expand without reducing the badge text size.

| Capture | UI state |
| --- | --- |
| [Light theme, 320 × 640](badge-320x640-light.png) | English (US), active, text scale 1.0, device scale factor 1, counts 1, 12, and 100 (`99+`). |
| [Dark theme, 320 × 640](badge-320x640-dark.png) | Same component state and viewport using the dark Material theme. |

The preview entry point is [`tools/qa/composer_badge_preview.dart`](../../../tools/qa/composer_badge_preview.dart). It imports and renders the production composer component. Build and serve a release web app with:

```sh
flutter build web --release --target tools/qa/composer_badge_preview.dart --output /tmp/composer-badge-preview
python3 -m http.server 8765 --bind 127.0.0.1 --directory /tmp/composer-badge-preview
```

Open `http://127.0.0.1:8765/?theme=light` or `?theme=dark` in a Chromium browser at a 320 × 640 CSS viewport and device scale factor 1. The committed captures were made with Flutter 3.47.9, Chromium 154.0.8037.57, and a 1× Flutter text scale.

The focused widget test verifies that the full `99+` value remains a semantic label and that a 2× text scale increases badge height. `tests/pages/chat/composer/composer_chip_badge_size_test.dart` also checks the 1, 12, and 99+ widths and retained text style; the existing `tests/pages/chat/composer/composer_model_name_truncation_test.dart` covers the SettingsChip `99+` display. No motion preview applies because this change does not animate text.
