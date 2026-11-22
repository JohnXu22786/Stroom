# Fullscreen chat edit-dialog heading

The capture opens the production chat composer edit dialog from a local fixture and shows its French heading at 320 × 640 CSS pixels with 2× text scaling. The heading is clipped beside the close control at the initial position; the playable preview shows the shared delayed horizontal reveal. The editor field is autofocus and focused. Chromium does not display a software keyboard, and the fixture contains no account data or network-backed content.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1
- Browser: Chromium headless with SwiftShader
- Renderer: Flutter Web release build using the local CanvasKit assets
- Locale and theme: `fr_FR`, Material 3 light
- Text scale: 2.0
- Fixture: production `ChatComposerWidget` and fullscreen editor dialog with local in-memory providers
- Build harness: `tools/qa/vertical_chat_edit_dialog_capture.dart`
- Capture script: `tools/qa/capture_vertical_chat_edit_dialog.py`

## Artifacts

- [Fullscreen edit dialog screenshot](edit-dialog-fr-320x640-scale2-light.png)
- [Playable heading reveal preview](edit-dialog-heading-motion.webm) — 9 seconds, 320 × 640, 8 fps, VP9

The screenshot is the initial clipped heading state. The preview records the title moving within its bounded row while the close control and native editable field remain visible.
