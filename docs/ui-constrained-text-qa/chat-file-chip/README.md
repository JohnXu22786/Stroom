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
- The long-name screenshot and WebM preview show the two-line viewport,
  vertical reveal, the 2 s endpoint pause, return, and the second 2 s endpoint
  pause. The 23 s preview includes the measured 1 s initial delay and both
  travel legs.

Run `python3 tools/qa/capture_chat_file_chip.py` from the repository root to
rebuild the screenshots and motion preview.
