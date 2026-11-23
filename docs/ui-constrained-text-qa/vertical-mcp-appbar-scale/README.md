# MCP server configuration AppBar at narrow widths

The production `showMcpServerConfigDialog` was rendered at 320 × 640 CSS px,
device pixel ratio 1, Material 3 light theme. The primary 1× capture uses
English (United States); Save and Discard keep their existing horizontal
AppBar row. The German (`de-DE`) 1× capture also keeps the original horizontal
row. The supplemental 2× German capture moves Save and Discard below the title
when the complete labels and icons no longer fit, and both remain operable.
Neither capture has a focused control or an open keyboard. The in-memory MCP
fixture uses an `example.invalid` endpoint and makes no provider or network
request.

- [320 × 640, en-US, 1× text](mcp-edit-en-320x640-scale1-light.png)
- [320 × 640, de-DE, 1× text](mcp-edit-de-320x640-scale1-light.png)
- [320 × 640, de-DE, 2× text](mcp-edit-de-320x640-scale2-light.png)

Before the fix, the focused 320 × 640 German widget run produced horizontal
RenderFlex overflows of 94 px at 1× and 298 px at 2×. The regression test now
checks those narrow states, covers French at 360 × 640/1× and the wide 1×
layout, verifies both action bounds, native field focus and keyboard visibility,
and Discard returning to read-only mode. The production captures show the
horizontal German 1× row and the reflow at 2×. Run the test with:

```sh
flutter test --reporter expanded --plain-name \
  'MCP AppBar actions adapt to localized width and text scale' \
  tests/widgets/mcp_settings_test.dart
```

The production capture is reproducible with
`python3 tool/qa/capture_vertical_mcp_appbar_scale.py`.
