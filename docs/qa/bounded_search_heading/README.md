# Bounded search heading QA

The production `SearchPanel` heading overflowed the close button slot on a 320 × 640 viewport with German text at 1.25× text scale. It now uses the shared `ConstrainedText` marquee only when its measured text exceeds the available heading width; the search icon and close action retain their positions.

## Captures

- [Light theme, German, 320 × 640, 1.25× text](search-panel-heading-de-320x640-scale1_25-light.png)
- [Dark theme, German, 320 × 640, 1.25× text](search-panel-heading-de-320x640-scale1_25-dark.png)
- [Playable light-theme heading reveal](search-panel-heading-de-320x640-scale1_25-light-motion.webm)

The PNGs and 12.76-second WebM were captured from a release Flutter Web build in headless Chromium at device pixel ratio 1, using the real `SearchPanel` widget and the app's seeded Material 3 color scheme. The preview shows the full localized heading moving within the title slot. Chromium reported no console or page errors.

The focused widget test uses the German locale, a 320 × 640 logical viewport, and 1.25× text scaling. It checks that the full localized heading is bounded by its header Row and that the heading Row no longer overflows. The second filter-chip row remains outside this unit; at the same narrow/high-scale state its trailing chip is clipped and is recorded as a separate follow-up candidate.
