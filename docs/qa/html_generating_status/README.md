# HTML generating status label

The production `HtmlCodeBlockWidget` now keeps the centered spinner and
localized generating status inside the card's available width. A short German
card label that clips reveals the complete value; a fitting label remains
stationary.

## Captures

- `narrow-de-320x640-scale1_8-light.png`: de-DE, 320 × 640 logical viewport,
  DPR 1, 1.8× text scale, 180 dp card, light Material 3 theme, streaming state.
- `fitting-en-1000x800-scale1-light.png`: English, 1000 × 800 logical
  viewport, DPR 1, 1× text scale, 480 dp card, light Material 3 theme,
  streaming state.

Both captures use the production widget with local static HTML and reduced
motion enabled so the clipped label is shown at rest. Rebuild the screenshots
with `python3 tool/qa/capture_html_generating_status.py`.
