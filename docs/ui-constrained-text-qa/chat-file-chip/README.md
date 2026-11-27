# Chat file preview chip text scaling

Captures use the production `PreviewChip` at a 320 × 640 CSS-pixel viewport,
DPR 1, en-US, and Material 3. The file is an in-memory fixture; the remove
callback is a no-op, no input is focused, and the software keyboard is closed.

- The scale 1 light and dark screenshots show the original 72 dp chip size and
  fitting filename.
- The scale 3 before-fix screenshot shows `annual.pdf` clipped by the original
  72 dp parent. The fixed screenshot shows the same exact two-line filename in
  full; Flutter Web measured two lines at 86 dp while the old parent left 56 dp
  after padding and did not trigger `maxLines: 2` overflow.
- The `chat-file-picker-dialog-annual-*` screenshots use the real
  `ChatFilePickerDialog` route with an in-memory `annual.pdf` record selected.
  At scale 1 the preview bar remains 106 dp and the chip remains 72 dp. At
  scale 3 the bar grows to fit the two-line chip while the dialog content and
  Done action remain in the viewport. The scale 3 route also exposes existing
  clipping in the fixed-height tab strip and selected-state AppBar actions;
  those adjacent controls are tracked separately and are not hidden by the
  chip regression.
- Production-route boundary tests derive the text slot from the rendered row
  after the 0.5 dp border inset, icon, gap, and padding. A `notes.pdf` natural
  width of 98.28 dp stays on one line in the 99 dp slot; 99.28 dp and 100.28 dp
  widths wrap to two visible lines with the chip and parent bar containing the
  full label bounds.
- The long-name screenshot and WebM preview show the two-line viewport,
  vertical reveal, the 2 s endpoint pause, return, and the second 2 s endpoint
  pause. The 23.125 s preview includes the measured 1 s initial delay, both
  travel legs, and the full final pause. The capture script timestamps the
  first long-name layout metric and repeats the first rendered still for the
  elapsed build-to-capture time. It also compensates for frame rounding so the
  initial still and final endpoint each remain visible for their full pauses.

Run `python3 tools/qa/capture_chat_file_chip.py` from the repository root to
rebuild the screenshots and motion preview.
