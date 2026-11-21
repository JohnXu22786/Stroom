# File details narrow phone captures

Captured from the production `showFileInfoPreviewDialog` in Chromium using the Flutter Web build. Viewport: 320 × 640 logical pixels at 1×, locale: en-US, theme: light, text scale: 1. The fixture has a 140-character unbroken filename and MIME component, plus a 600-character unbroken storage-path component.

- `file-info-en-us-light-320x640-top.png`: dialog at its initial scroll position, with long filename and type values wrapped and the path continuing below the fold.
- `file-info-en-us-light-320x640-close.png`: dialog scrolled to the path tail and close action.

## Arabic shaping comparison

Captured from the production file details dialog in Flutter Web / Chromium at 320 × 640 logical pixels, 1×, en-US, light theme, text scale 1. The fixture uses the fitting Arabic filename `تقرير.pdf` and Arabic path `/home/المستخدم/ملفات/تقرير.pdf`.

- `file-info-arabic-before-320x640.png`: PR head `55a472f`, with break characters inserted between every grapheme.
- `file-info-arabic-after-320x640.png`: follow-up implementation, which adds emergency breaks only inside overlong unbroken segments.

The before/after production render differs in the Arabic filename and path: the original head visibly split the connected Arabic glyph forms, while the follow-up preserves joined shaping and the normal reading order. Chromium pixel comparison reported 3,670 changed pixels within the text and dialog content bounds.
