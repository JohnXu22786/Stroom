# Mermaid editor label captures

`editor_mode_320x640.png` shows the production `MermaidChartPage` mode popup in
Portuguese (Brazil), light theme, at 320 × 640 logical pixels, device scale
1.0, and text scale 1.0. The popup is open with Edit selected. The published
Portuguese labels fit in this state and remain stationary.

`marquee_preview_320x640.gif` is a playable capture of the same production
popup using a deliberately extended Portuguese test translation for the split
mode. It is captured at the same viewport and scales to show the initial
stationary interval followed by horizontal label motion. This longer string is
a test fixture, not a production translation. The matching screenshot golden
for the normal localized popup is
[`tests/pages/content/goldens/mermaid_editor_mode_320x640.png`](../../../tests/pages/content/goldens/mermaid_editor_mode_320x640.png).

`split_code_header_320x640.png` shows the production split editor with a long
test-only Portuguese code header. The header is clipped to its remaining row
width, and the Mermaid source remains editable below it.
