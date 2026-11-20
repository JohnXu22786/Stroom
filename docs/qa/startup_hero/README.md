# Startup hero text sizing

These captures show the production `StartupPage` in a temporary Flutter Web harness. The hero keeps its original text sizes at constrained heights; short landscape uses tighter card spacing and keeps startup feedback visible, while detailed or enlarged-text layouts can scroll instead of scaling the entire card down. The `FOCUS FLOW` and `Stroom` labels use `ConstrainedText`; the localized tagline wraps naturally.

## Captures

- [320 × 640, English, text scale 1.0](startup-320x640-1x.png)
- [640 × 320, English, text scale 1.0](startup-short-640x320-1x.png)
- [320 × 640, zh-CN, text scale 2.0](startup-zh-scale2-320x640.png)
- [Playable label reveal preview](startup-brand-label-reveal.webm)

Captured from Flutter 3.47.9 in headless Chromium at device pixel ratio 1. The localized capture includes enlarged text; the video shows the existing horizontal reveal of the clipped brand/header labels. No browser page errors occurred.
