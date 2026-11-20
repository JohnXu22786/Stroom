# Background optimization status label QA

At 320 × 640 CSS px, device scale 1, the localized German status is rendered in the production `BackgroundOptimizationPage`. The status icon remains in its leading position, and the status string receives the remaining row width. The new single-line `ConstrainedText` reveals the clipped text horizontally while retaining the full accessible label.

The widget regression test also renders the German desktop tray status at 320 × 640 and confirms no layout exception, a one-line constrained slot, and the complete accessible string. At the original base, this exact state reported an 18 px RenderFlex overflow.

Captured with Flutter 3.47.9 / Dart 3.13.7 and Chromium at 320 × 640, device scale 1. The screenshot shows a frame near the trailing reveal endpoint. No browser errors occurred.

- [Rendered screenshot, 320 × 640, 1×](german-320x640-1x.png)
- [Playable 16 second text reveal](status-label-reveal-16s.webm)
