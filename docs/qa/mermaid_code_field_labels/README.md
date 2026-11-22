# Mermaid code field label captures

The capture uses the production `MermaidChartPage` in code-only edit mode at
320 × 640 CSS pixels, DPR 1, 1× text scale, English, and the light Material 3
theme. The field has focus and the native Flutter code editor remains visible
and editable. Chromium is running on desktop, so no software keyboard is
present. The capture uses the production Roboto font; only the English field
label is extended to exercise clipping.

- [Focused code editor field, 320 × 640, 1×](code-field-en-320x640-1x-light-focused.png)
- [Wide split editor and live chart preview, 640 × 320, 1×](wide-split-640x320-1x-light.png)
- [Playable reveal preview](code-field-label-reveal-en-320x640-1x.webm)

`tools/qa/mermaid_code_field_labels_capture.dart` launches the production chart
page with a deliberately extended English label. The preview shows the label
remaining stationary for its initial delay, then revealing the clipped text
inside the field. The Mermaid source remains native editable text throughout.
The wide capture shows the production split layout with its Mermaid chart
preview and the same field label in the adjacent editor pane.
