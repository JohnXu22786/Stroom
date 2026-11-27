# Compact voice duplicate indices

The captures use the production `DuplicateResolveDialog` with in-memory duplicate entries and French localization.

- `voice-index-fitting-1x.png`: 600×640 viewport, 1× text scale, one entry. The numeric prefix keeps its 28 dp minimum width.
- `voice-index-scaled-high-count-2x.png`: 1000×1200 viewport, 2× text scale, 1,234 entries. The capture is scrolled to entries 1,215–1,234; their complete indices remain on one line and the update/skip actions remain visible.

The regression test checks the 1× width, the responsive single-line width at 2×, and both actions. The index does not animate: its slot expands to the text's natural width as needed.

Recreate the screenshots with:

```sh
python3 tools/qa/capture_compact_row_voice_index.py
```
