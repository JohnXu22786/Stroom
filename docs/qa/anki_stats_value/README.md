# Anki statistics value bounds

These screenshots render the production `AnkiStatsPage` with a local in-memory
database fixture. The fixture contains 9,876,543 total cards and a small set of
other statistics; it does not open a database or make network requests. All
captures use English (United States), device pixel ratio 1, no focused controls,
and a closed keyboard.

- [Large count, 320 × 640 logical pixels, 3× text scale](large-count-320x640-scale3-light.png): the seven-digit value is clipped within its responsive slot while the icon stays in place. Reduced motion is enabled; hovering or long-pressing the value opens its complete tooltip.
- [Reduced-motion tooltip, 320 × 640 logical pixels, 3× text scale](reduced-motion-value-tooltip-320x640-scale3-light.png): the tooltip displays the complete count without moving the clipped label.
- [Large count in dark theme, 320 × 640 logical pixels, 3× text scale](large-count-320x640-scale3-dark.png): confirms the same bounded layout against the dark Material 3 surface.
- [Fitting count, 800 × 1200 logical pixels, 1× text scale](fitting-count-800x1200-scale1-light.png): values retain the original stationary text rendering and right-edge placement.

The capture entrypoint is `tool/qa/anki_stats_value_capture.dart`; run
`tools/qa/capture_anki_stats_value.py` while serving it with Flutter Web on port
8899.
