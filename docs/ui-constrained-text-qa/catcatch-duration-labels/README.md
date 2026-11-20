# CatCatch duration label capture

This is a real Flutter Web release rendering of the production `CatCatchPage`, with the page's normal Spanish translations and the local URL `https://example.com/video` entered in its URL field. Duration values are empty, the editor is idle, and the keyboard is closed. The long Spanish second-field label is deliberately clipped at its initial position; the playable preview shows the constrained label moving to reveal its remaining text.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1 (1×)
- Browser: Chromium headless with SwiftShader
- Renderer: Flutter Web release build using the local CanvasKit assets
- Locale and theme: `es-ES`, Material 3 light
- Text scale: 1.0
- Build harness: `/tmp/catcatch_duration_capture.dart`, which mounts the real `CatCatchPage` in a localized `MaterialApp`

## Artifacts

- [Still screenshot](catcatch-duration-labels-es-320x640-scale1-light.png)
- [Playable motion preview](catcatch-duration-labels-motion.webm) — 8.5 seconds, 320 × 640, 2 fps, VP9

The animation was captured from the live release page over 8.5 seconds. The screenshot records the initial clipped label state; the preview records the label's reveal motion. Both artifacts are genuine browser captures, not reconstructed mockups.
