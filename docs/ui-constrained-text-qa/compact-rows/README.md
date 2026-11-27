# Compact voice duplicate indices

The captures use the production `DuplicateResolveDialog` with in-memory duplicate entries and French localization.

- `voice-index-fitting-1x.png` and `voice-index-fitting-1x-dark.png`: 600×640 viewport, 1× text scale, one entry. The numeric prefix keeps its 28 dp minimum width.
- `voice-index-scaled-high-count-2x.png` and `voice-index-scaled-high-count-2x-dark.png`: 1000×1200 viewport, 2× text scale, 1,234 entries. The capture is scrolled to entries 1,215–1,234; their complete indices remain on one line and the update/skip actions remain visible.
- `voice-index-scaled-narrow-2x.png` and `voice-index-scaled-narrow-2x-dark.png`: 440×932 viewport, 2× text scale, 1,234 entries. The action buttons reflow below the index/ID when their measured widths do not fit inline.
- `voice-index-rtl-narrow-2x.png` and `voice-index-rtl-narrow-2x-dark.png`: 320×932 viewport, 2× text scale, one Arabic entry. Its actions reflow below the index/ID and remain on the RTL trailing edge.

The regression test checks the 1× width, the responsive single-line width at 2×, the narrow action reflow, and both actions. The index does not animate: its slot expands to the text's natural width as needed.

An Arabic/RTL widget regression verifies that reflowed actions stay on the directional trailing edge.

Captures emulate reduced motion so the unrelated, clipped dialog heading remains at a stable frame.
At 2× text scale that heading is visually ellipsized to one line, while the reduced-motion widget regression verifies its full localized title remains available as the semantics label.

Recreate the screenshots with:

```sh
python3 tools/qa/capture_compact_row_voice_index.py
```
