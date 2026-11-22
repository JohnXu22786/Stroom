# Voice editor responsive actions

The voice editor action bar stacks its add-row and batch-add controls on narrow
viewports and when text scaling needs additional room. The wide layout retains
the existing inline arrangement. Button callbacks, native voice fields, and
label semantics remain unchanged.

- ![German voice editor actions at 320 × 640, 1× device scale, 2× text scale, light theme](voice-editor-actions-de-320x640-scale2-light.png)

This is a genuine Flutter Web capture of `VoiceEditorPage` using an empty local
voice list. The state is German (`de_DE`), light theme, no focused control, and
keyboard closed. No provider calls or voice synthesis are made. Start the app
with:

```sh
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8874 --target tool/qa/voice_editor_actions_capture.dart
```

Then capture the screen with:

```sh
python3 tool/qa/voice_editor_actions_capture.py
```
