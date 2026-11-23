# Vertical media preview scrolling

The production media preview sheet keeps audio metadata and playback controls
reachable when the viewport is short, and lets users scroll through long
initialization diagnostics. The 1× and short-viewport screenshots show playback controls after scrolling
within the sheet. The 2× text-scale screenshot shows the start of the naturally
wrapped content; the widget regression test verifies the controls remain
reachable at that scale.

## Capture setup

- Viewport: 320 × 640 logical pixels at 1× and 2× text scale; supplemental
  capture at 240 × 400 logical pixels and 1× text scale
- Locale: en-US
- Theme: Material 3 light
- Focus: none; keyboard closed
- Fixture: in-memory audio metadata and a mocked player; no download or network
  request is made
- The production `MediaPreviewSheet` is mounted in a modal bottom sheet with
  its normal width constraints.

## Artifacts

- [320 × 640 at 1× text scale](audio-preview-en-320x640-scale1-light.png)
- [320 × 640 at 2× text scale](audio-preview-en-320x640-scale2-light.png)
- [240 × 400 at 1× text scale](audio-preview-en-240x400-scale1-light.png)

Recreate with
`flutter test --update-goldens tests/qa/media_preview_sheet_scroll_capture_test.dart`.
