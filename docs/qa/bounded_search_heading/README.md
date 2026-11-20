# Bounded search heading QA

The production `SearchPanel` heading overflowed the close button slot on a 320 × 640 viewport with German text at 1.25× text scale. It now uses the shared `ConstrainedText` marquee only when its measured text exceeds the available heading width; the search icon and close action retain their positions.

## Primary acceptance capture

- [German, 320 × 640, 1× text, light theme](search-panel-heading-de-320x640-scale1-light.png)

The German heading fits at normal text size and remains fully visible and stationary. This is the primary acceptance state.

## Enlarged-text overflow evidence

- [Light theme, German, 320 × 640, 1.25× text](search-panel-heading-de-320x640-scale1_25-light.png)
- [Dark theme, German, 320 × 640, 1.25× text](search-panel-heading-de-320x640-scale1_25-dark.png)
- [Playable light-theme heading reveal](search-panel-heading-de-320x640-scale1_25-light-motion.webm)

All captures were rendered by the release Flutter Web build in headless Chromium at a 320 × 640 CSS viewport and device pixel ratio 1, using the real `SearchPanel` widget and the app's seeded Material 3 color scheme. The primary capture uses 1× text; the supplementary PNGs and 12.76-second WebM use 1.25× text. The preview shows the full localized heading moving within the title slot. Chromium reported no console or page errors.

The focused widget test uses the German locale, a 320 × 640 logical viewport, and 1.25× text scaling. It checks that the full localized heading is bounded by its header Row and that the heading Row no longer overflows. The second filter-chip row remains outside this unit; at the same narrow/high-scale state its trailing chip is clipped and is recorded as a separate follow-up candidate.
