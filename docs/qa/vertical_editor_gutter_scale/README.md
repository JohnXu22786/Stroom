# Scaled code line-number gutters

Both production code displays measure the final line number using their active
text style and `TextScaler`. The editor also keeps its existing caret-based
line-height measurement, so a wider scaled gutter naturally reflows wrapped
text while line numbers continue to follow the editable content.

The screenshots show 1,234-line local fixtures at 320 × 640 logical pixels,
de-DE, light theme, and 1× / 2× text scales. The JSON editor is focused and
scrolled to the last lines; the code block has no focused control and is
scrolled to the last lines. The software keyboard is closed in every capture.
No account data or network requests are used.

- [1× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/editor-gutter-de-320x640-scale1-light.png)
- [2× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/editor-gutter-de-320x640-scale2-light.png)
- [Code block at 1× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/code-block-gutter-de-320x640-scale1-light.png)
- [Code block at 2× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/code-block-gutter-de-320x640-scale2-light.png)

Capture with `python3 tool/qa/capture_vertical_editor_gutter_scale.py`. The
safe fixture entrypoint is `tool/qa/vertical_editor_gutter_scale_capture.dart`.
Focused widget tests are owned by `vertical_gutter_width_scale` in
`tests/widgets/code_block_source_widget_test.dart` and
`tests/widgets/code_editor_field_test.dart`. They check four-digit gutter fit
at both scales; the editor test additionally covers scaled soft-wrap alignment,
edits, RTL, and scrolling to the last line.
