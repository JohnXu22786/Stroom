# Recording action reflow QA

These screenshots show the production `RecordingActionGroup` and `RecordingActionButton` at a 320 × 640 CSS-pixel viewport, device scale factor 1, English (United States), light Material 3 theme, and normal 1× text scale. The recording pair stacks at 320 px with 24 px side insets; at 400 px the same pair stays on one row. Paused and completed pairs also stack at 320 px.

- [Recording actions, 320 × 640](recording-320x640-1x-en-light.png)
- [Paused actions, 320 × 640](paused-320x640-1x-en-light.png)
- [Completed actions, 320 × 640](completed-320x640-1x-en-light.png)
- [Recording actions, 400 × 640](recording-400x640-1x-en-light.png)

The temporary Flutter Web host uses the actual production `RecordingActionGroup`, `RecordingActionButton`, button dimensions/styles, and generated English localization strings. It is a component harness, not the full `AudioRecordingPage`: the `00:15` timer and recording/paused status badges are fixture content, and it does not render the waveform or page permission flow. Action callbacks are no-ops. No audio plugin, microphone, provider, or network request is used. There are no test-only action labels.

Captures were rendered from a Flutter 3.47.9 / Dart 3.13.7 release Web build in headless Chromium 154.0.8037.57 at 1× text scale. No control is focused and the keyboard is closed. Chromium reported no page errors. No playable preview applies because this change adds no motion.

To reproduce from the repository root:

```sh
flutter build web --release --no-pub --target tool/qa/recording_actions_capture.dart --output /tmp/stroom-recording-actions-web --no-wasm-dry-run
python3 -m http.server 8874 --directory /tmp/stroom-recording-actions-web
python3 tool/qa/recording_actions_capture.py
```
