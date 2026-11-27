# Media picker selected filename chip

The production multi-select media picker now measures selected filenames at
their active text scale and reserves enough room for the first three wrapped
lines. The chip keeps its original 72 dp minimum size, width, centering, and
remove action. Text beyond three lines continues to use the existing vertical
`ConstrainedText` reveal.

The captures use a 320 × 640 CSS-pixel viewport, DPR 1, light Material 3 theme,
and local in-memory records only:

- [Fitting filename at 1×](fitting-name-320x640-scale1-light.png)
- [Three-line filename (`one two three`) at 2×](three-line-name-320x640-scale2-light.png)
- [Before fix: third line clipped at 2×](three-line-name-before-320x640-scale2-light.png)
- [Long filename with reduced motion at 2×](overflow-name-320x640-scale2-reduced-motion.png)
- [Playable long-filename reveal at 2×](overflow-name-reveal-preview.webm)

The widget test verifies that the short filename retains the 72 dp list height,
the three-line filename gets enough room at 2×, and the selected chip keeps its
72 dp surface width and remove-button position. It checks that a longer name
still moves vertically after the initial one-second hold, pauses when
`TickerMode` is disabled, resumes when enabled, and stays static with reduced
motion. The complete filename remains present in the widget semantics.

The overflow fixture uses `media picker selected filename 123456789 extra.txt`.
The 27-second WebM starts with the label stationary, shows the forward reveal,
the two-second endpoint pause, and the reverse reveal back to the start. The
static 2× image shows the clipped state with reduced motion enabled.

The before capture uses the unchanged base commit and the same `one two three`
fixture. It shows only `one` and `two` in the 72 dp chip. The after capture
shows all three lines in a 96 dp surface. At 2×, the measured line boxes total
87 dp; 4 dp of vertical padding on both sides plus a 1 dp border allowance
leaves 87 dp for the text. The chip remains 72 dp wide and its remove action
stays 6 dp above its top edge.

Regenerate the production captures with:

```sh
python3 tools/qa/capture_media_picker_preview_chip.py
```
