# Anki Cloze label at a narrow viewport

The [screenshot](anki-cloze-de-320x640-1x-light-focused.png) shows the production add-card dialog on a 320 × 640 CSS-pixel viewport at device scale 1. The locale is German (`de-DE`), the theme is the app's blue-seeded Material 3 light theme, text scale is 1, the Cloze field is focused, and the headless browser has no software keyboard.

The [playable preview](anki-cloze-de-label-reveal-320x640-light.webm) shows the clipped localized label moving inside its field label slot. The field remains a native editable `TextField`.

The capture uses an in-memory deck and Basic/Cloze note-type fixture. It does not submit the form or make network or database calls. Rebuild and capture with:

```sh
flutter build web --target tool/qa/anki_cloze_label_capture.dart --output /tmp/stroom-anki-cloze-web
python3 tool/qa/anki_cloze_label_capture.py
```
