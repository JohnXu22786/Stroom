# Task-flow duration input labels

The screenshot shows the production `TaskFlowBuilderPage` time editor at 320 × 640 CSS px, device scale factor 1, Spanish (`es-ES`), Material 3 light theme, and normal 1× text. Its in-memory CatCatch flow starts with a local example URL and 42 seconds; no task is launched. The fields are unfocused and the software keyboard is closed. Motion is frozen for this still capture so the initial clipped label positions can be inspected; the narrow hour and second slots visibly clip their longer Spanish labels.

The playable preview uses the same production page and local flow at 320 × 640, `es-ES`, light theme, and 2× text scale. The Spanish `segundo` field label clips in its native field slot and the shared `ConstrainedText` reveals it horizontally; the numeric field stays an ordinary editable `TextField`.

## Artifacts

- [Production time editor, 1×](task-flow-duration-es-320x640-scale1-light.png)
- [Clipped localized label motion preview, 2×](task-flow-duration-label-motion-320x640.webm)

## Capture and verification

The capture harness imports the real `TaskFlowBuilderPage` and seeds only an in-memory flow. Build with `flutter build web --release --no-pub --target tool/qa/task_flow_duration_labels_capture.dart --output /tmp/task-flow-duration-labels-web --no-wasm-dry-run`, serve that output on port 8874, then run `python3 tool/qa/capture_task_flow_duration_labels.py`. Chromium reported no page errors. The focused widget test in `tests/task_flow/pages/task_flow_builder_page_constrained_run_rows_test.dart` checks all three localized labels, enters a new seconds value, confirms the live preview changes, and verifies the native editable text remains focused without layout exceptions.
