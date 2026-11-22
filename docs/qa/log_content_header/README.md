# Log content header QA

The screenshot and motion preview show the production `LogContentPage` app bar with a long filename and localized line count in the finite title slot.

- Chromium rendering of Flutter Web at 320 × 640 CSS pixels, device scale factor 1, English (US), light theme, default 1× text scale.
- The screenshot is a real component capture; the filename is visible at its current horizontal reveal position and the complete value remains available to semantics.
- The 18-second WebM preview records the normal bidirectional filename reveal, including its initial hold, from the same production page and viewport.
- `tests/pages/log_viewer_page_test.dart` covers 320 × 640 at 1.8× text scale in light and dark themes and verifies that the filename/count use `ConstrainedText`, toolbar actions remain present, the toolbar grows, and no layout exception occurs.
