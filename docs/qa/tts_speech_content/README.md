# TTS speech-content label

The screenshots show the production `TTSCreatePage` in Flutter Web at device pixel ratio 1. They use the blue-seeded Material 3 light theme, reduced motion, and a new synthesis form with a local TTS provider fixture. No field is focused, no software keyboard is open, and the fixture makes no provider request. The Arabic (`ar`) and Brazilian Portuguese (`pt-BR`) 3× captures use a 320 × 640 logical viewport and are scrolled 120 logical pixels so the section heading and text field are visible. The pt-BR 1× capture uses a 600 × 640 logical viewport, stays at the top of the page, and shows the full fitting label in its stationary position.

- [Arabic, 320 × 640, 3×](speech-content-ar-320x640-scale3-light.png)
- [Brazilian Portuguese, 320 × 640, 3×](speech-content-pt-BR-320x640-scale3-light.png)
- [Brazilian Portuguese, 600 × 640, 1×](speech-content-pt-BR-600x640-scale1-light.png)

Capture with `flutter build web --release --no-pub --target tool/qa/tts_speech_content_capture.dart --output /tmp/stroom-tts-speech-content-web --no-wasm-dry-run`, serve the output at `127.0.0.1:8877`, then run `python3 tool/qa/capture_tts_speech_content.py`.
