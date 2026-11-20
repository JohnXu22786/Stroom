# Bounded media picker back row

The media picker's back row now constrains its localized parent-folder label and current-folder basename independently. Short values keep their original left and right alignment; long values reveal their full text within the row without moving the back arrow or changing folder navigation.

## Captures

- [Fitting German labels, 320 × 640, 1× text, light theme](de-fitting-320x640-1x.png)
- [Long German labels, 320 × 640, 1× text, light theme](de-light-320x640-1x.png)
- [Portuguese Brazil capture, 320 × 640, 1.5× text, dark theme](pt-dark-320x640-1_5x.png)
- [Chinese capture, 320 × 640, 1× text, light theme](zh-light-320x640-1x.png)
- [Playable 12-second back-row text reveal](back-row-motion-320x640-1x.webm)

The captures use the production `showMediaPickerDialog` and `ConstrainedText` in a temporary Flutter Web fixture, rendered with Flutter 3.47.9 and headless Chromium at a 320 × 640 CSS viewport and device scale factor 1. The fixture supplies both a short two-level path and a two-level path with long names. The fitting capture confirms the current-folder basename remains against the row’s trailing edge while the parent label stays at the leading edge. The motion preview is cropped to the production back-row card and shows both complete folder labels moving within their slots. The final captures had no browser console or page errors.

The targeted widget regression test reproduces the prior 22 px RenderFlex overflow with long folder names at 320 × 640, then verifies the back row remains error-free and continues to navigate to the parent and root folders.
