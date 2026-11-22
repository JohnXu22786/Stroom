# Block-editor duration labels

The still capture shows the production `showBlockEditorDialog` for a built-in CatCatch block at 320 × 640 CSS px, device scale factor 1, Spanish (`es-ES`), Material 3 light theme, and 1× text. The duration fields are unfocused, and the software keyboard is closed. The editor is scrolled to the duration row. Its fixture uses only the built-in block and empty in-memory provider and assistant state; it makes no provider request and does not launch a task.

The playable preview uses the same production dialog and fixture at 320 × 640, `es-ES`, light theme, and 2× text scale. The hour, minute, and second labels reveal only where clipping occurs. The numeric controls remain ordinary editable `TextField`s.

## Artifacts

- [Production block-editor duration fields, 1×](block-editor-duration-es-320x640-scale1-light.png)
- [Clipped localized label motion preview, 2×](block-editor-duration-label-motion-320x640.webm)

## Capture and verification

Build with `flutter build web --release --no-pub --target tool/qa/block_editor_duration_capture.dart --output /tmp/block-editor-duration-web --no-wasm-dry-run`, serve that output on port 8878, then run `python3 tool/qa/capture_block_editor_duration.py`. The capture script checks for browser errors and a nonblank screenshot.
