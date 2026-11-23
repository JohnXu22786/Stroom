# Message save destination dialog

The capture uses the production `showMessageSaveDestinationDialog` in a local
Flutter Web fixture. The French device-save label is clipped at this narrow
width and reveals horizontally after the shared initial hold. The dialog keeps
its existing icons, button actions, typography, and button sizing; its complete
label remains available to accessibility services.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1
- Browser: Chromium headless with SwiftShader
- Locale and theme: `fr_FR`, Material 3 light
- Text scale: 1.0
- Focus and keyboard: no focused control; browser keyboard closed
- Fixture: production dialog opened from `tools/qa/vertical_save_destination_capture.dart`; no account data or network-backed content
- Capture script: `tools/qa/capture_vertical_save_destination.py`

To reproduce the artifacts, start the fixture from the repository root:

```sh
flutter run --release --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8897 -t tools/qa/vertical_save_destination_capture.dart
```

Then run `python3 tools/qa/capture_vertical_save_destination.py` in a second
terminal.

## Artifacts

- [Save destination dialog at 1×](save-destination-fr-320x640-scale1-light.png)
- [Playable French label reveal](save-destination-fr-320x640-label-reveal.webm) — 9 seconds, 320 × 640, 8 fps, VP9
