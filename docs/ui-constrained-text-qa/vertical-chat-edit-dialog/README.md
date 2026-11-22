# Fullscreen chat edit-dialog heading

The primary capture opens the production chat composer edit dialog from a local fixture at 320 × 640 CSS pixels with French text at the normal 1× scale. A supplemental 2× capture shows the heading clipped beside the close control; the playable preview shows the shared delayed horizontal reveal at that scale. The editor field is autofocus and focused in both captures. Chromium does not display a software keyboard, and the fixture contains no account data or network-backed content.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1
- Browser: Chromium headless with SwiftShader
- Renderer: Flutter Web release build using the local CanvasKit assets
- Locale and theme: `fr_FR`, Material 3 light
- Text scales: 1.0 primary screenshot; 2.0 supplemental screenshot and motion preview
- Fixture: production `ChatComposerWidget` and fullscreen editor dialog with local in-memory providers
- Build harness: `tools/qa/vertical_chat_edit_dialog_capture.dart`
- Capture script: `tools/qa/capture_vertical_chat_edit_dialog.py`

## Artifacts

- [Fullscreen edit dialog screenshot at 1×](edit-dialog-fr-320x640-scale1-light.png)
- [Scaled supplemental screenshot at 2×](edit-dialog-fr-320x640-scale2-light.png)
- [Playable heading reveal preview at 2×](edit-dialog-heading-motion.webm) — 9 seconds, 320 × 640, 8 fps, VP9

The primary screenshot shows the normal text-scale layout. The supplemental image and preview record the clipped-title state and motion while the close control and native editable field remain visible.
