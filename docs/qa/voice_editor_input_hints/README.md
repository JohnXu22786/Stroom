# Voice Editor input hints

These captures use the production `VoiceEditorPage` with one empty voice row, Spanish (`es_ES`), light Material 3, and 1× text scale. The narrow viewport reproduces the localized hint clipping at 320×640 CSS pixels; the 800×640 capture shows both hints fitting without movement. The 9-second WebM records the live clipped-hint reveal at 10 fps.

- [Narrow clipped hints](voice-editor-hints-es-320x640-1x-light.png)
- [Fitting hints](voice-editor-hints-es-800x640-1x-light.png)
- [Playable reveal preview](voice-editor-hints-reveal-es-320x640-1x-light.webm)

Reproduce from the repository root. Build first. Start the HTTP server in a
second terminal, then run the capture script in a third terminal (or after the
server has started in the background):

```sh
flutter build web --no-pub --release --target tool/qa/voice_editor_hint_capture.dart --output build/voice-editor-input-hints
python3 -m http.server 8876 --bind 127.0.0.1 --directory build/voice-editor-input-hints
python3 tool/qa/voice_editor_hint_capture.py
```

The focused production-widget regression test is `flutter test --no-pub --reporter expanded tests/task_flow/voice_editor_page_constrained_hints_test.dart`.
