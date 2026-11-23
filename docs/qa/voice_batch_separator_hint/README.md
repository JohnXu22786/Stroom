# Custom separator hint

The screenshot shows the production `VoiceBatchAddPage` in Flutter Web at 320 × 640 CSS pixels, device scale 1, German (`de_DE`), the light Material 3 theme, and 1× text scale. The custom separator option is selected; its empty native text field is focused. Headless desktop Chromium has no software keyboard. The page uses an empty local voice list and makes no provider or network requests.

- [Production UI screenshot](voice-batch-separator-hint-de-320x640-1x-light.png)
- [Real-time clipped-hint reveal preview](voice-batch-separator-hint-reveal-de-320x640-1x-light.webm) — 9 seconds, recorded at 10 fps from the same focused production page with no speed adjustment.

Reproduce the capture with Flutter Web release mode. Build first; run the server in one terminal, then run the capture script in another:

```sh
flutter build web --no-pub --release --target tool/qa/voice_batch_separator_capture.dart --output build/voice-batch-separator-hint
python3 -m http.server 8875 --bind 127.0.0.1 --directory build/voice-batch-separator-hint
python3 tool/qa/voice_batch_custom_separator_hint_capture.py
```

The focused widget test measures the localized hint at its actual field width, checks the complete semantic label at 1× and 2× text scale, and verifies keyboard focus and that entered separator text remains in the native editable field with its caret at the end.
