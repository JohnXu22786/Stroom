# CatCatch floating capture action

This browser capture mounts the production `DraggableFloatingPanel` with a
local synthetic media URL. The still shows the full, stationary panel title,
selected resource, and enabled capture action. The large-text preview shows the
resource URL's vertical reveal while the capture action grows to fit the scaled
label.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1
- Browser: headless Chromium
- Locale: `zh-CN` (the panel's existing Chinese labels)
- Still: Material 3 light theme, text scale 1.0
- Preview: Material 3 light theme, text scale 3.0
- State: the demo video row is selected; no text input is focused; keyboard
  closed
- Fixture: `https://example.test/demo-video.mp4`; no media is fetched
- Runtime: Flutter Web debug renderer; no browser page errors

## Artifacts

- [320 × 640 production widget screenshot](capture-button-zh-CN-320x640-scale1-light.png)
- [Large-text reveal preview](capture-button-zh-CN-320x640-scale3-light.webm) —
  10 seconds, 6 fps, VP9

Recreate both artifacts with
`python3 tools/qa/capture_vertical_floating_capture_button.py`.
