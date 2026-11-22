# Task Flow metadata row QA

The captures render the production `TaskFlowListPage` with one saved flow containing 99 OCR blocks. The flow was last updated five hours earlier. Temporary capture entrypoints supplied this state and were removed after capture; all captured pixels come from the app's real Flutter Web rendering.

## Conditions

- Chromium 154 / Flutter 3.47.9 / Dart 3.13.7
- 320 × 640 CSS px viewport, device scale factor 1
- pt-BR locale; the primary capture uses normal 1× text scale, while supplemental captures use 4× text scale in light and dark themes
- The metadata row receives the available width after its icon; localized count and timestamp keep their original placement when their measured widths fit. When their combined width exceeds the row, each value gets a measured slot and the shared `ConstrainedText` reveal preserves the complete value.
- No browser page errors during capture

## Captures

- Primary: [normal text scale, light theme](pt-br-320x640-1x-light.png)
- Large-text supplement: [light theme](pt-br-320x640-4x-light.png), [dark theme](pt-br-320x640-4x-dark.png)
- [Eight-second metadata row reveal preview](pt-br-block-count-reveal.webm)
