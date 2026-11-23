# Scaled code editor gutter

The shared production JSON editor aligns its line-number rows to the actual
scaled text-line metrics. The screenshots show the dialog at 320 × 640 logical
pixels in de-DE, light theme, with the editor focused and the software keyboard
closed. The JSON fixture is local and does not use account data or make network
requests.

- [1× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/editor-gutter-de-320x640-scale1-light.png)
- [2× text scale](../../ui-guidelines/images/ui-constrained-text-qa/vertical-editor-gutter-scale/editor-gutter-de-320x640-scale2-light.png)

Capture with `python3 tool/qa/capture_vertical_editor_gutter_scale.py`. The
fixture entrypoint is `tool/qa/vertical_editor_gutter_scale_capture.dart`.
The focused widget test checks line-row pitch and a long soft-wrapped line at
1× and 2×, edits the multiline source at both scales, then scrolls to the end
and checks the final logical line number remains visible and aligned.
