# HTML preview dialog top bar

The screenshot shows the production fullscreen HTML preview dialog opened from a safe local fixture. Both the edit-source and close controls are visible. It uses a 320 × 640 CSS-pixel viewport, device pixel ratio 1, zh-CN, Material 3 light theme, and normal 1× text scale. No control is focused, the keyboard is closed, and the preview contains no account data or external resource requests.

## Capture setup

- Fixture: `tools/qa/html_preview_dialog_capture.dart`
- Capture script: `tools/qa/capture_html_preview_dialog.py`
- Build: `flutter run --release --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8898 -t tools/qa/html_preview_dialog_capture.dart`

## Artifact

- [HTML preview top bar at 1×](html-preview-zh-320x640-scale1-light.png)
