# Task Flow fallback subtask status

The screenshots show the production `TaskFlowCard` with a local fallback step at 320 × 640 CSS px, device scale factor 1, German (`de-DE`), Material 3 light and dark themes, and normal 1× text. The flow is interrupted so its fallback subtask status is visible. No task runs, account data is used, or network request is made. The status fits and stays stationary; no control is focused and the keyboard is closed.

The playable preview uses the same production widget at 320 × 640, Arabic (`ar-SA`), light theme, and 1.5× text scale. Its localized interruption status clips in the trailing row slot and reveals horizontally while preserving the full accessible label.

## Artifacts

- [Production card screenshot at 1×](flow-subtask-status-de-320x640-scale1-light.png)
- [Dark-theme card screenshot at 1×](flow-subtask-status-de-320x640-scale1-dark.png)
- [Playable clipped-status preview](flow-subtask-status-motion-320x640.webm)

## Capture

Build the fixture with `flutter build web --release --no-pub --target tool/qa/vertical_flow_subtask_status_capture.dart --output /tmp/vertical-flow-subtask-status-web --no-wasm-dry-run`, serve that directory on port 8880, then run `python3 tool/qa/capture_vertical_flow_subtask_status.py`. The fixture seeds only in-memory flow status data.
