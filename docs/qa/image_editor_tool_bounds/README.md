# Image editor tool labels at narrow width

The production image editor keeps all four tools in equal-width slots at a
320 dp viewport. The French rotate labels move only because they are clipped;
the complete action names remain available to assistive technology. Tool icons,
colors, sizing, and callbacks are unchanged.

- [Production screen, 320 × 640, 1×](image-editor-fr-320x640-1x-light.png)
- [Playable label reveal preview](image-editor-label-reveal-fr-320x640-1x.webm)

These are Flutter Web captures of `ExtendedImageEditorPage` at 320 × 640 CSS
pixels, device pixel ratio 1, and text scale 1. The locale is French (`fr_FR`),
the theme is light, no control is focused, and the keyboard is closed. The
editor loads a generated synthetic image kept in memory; no user files or
network services are used.

Recreate the captures with:

```sh
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8874 --target tool/qa/image_editor_tool_bounds_capture.dart
python3 tool/qa/image_editor_tool_bounds_capture.py
```
