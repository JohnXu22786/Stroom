# MCP server configuration AppBar at narrow widths

The production `showMcpServerConfigDialog` was rendered at 320 × 640 CSS px,
device pixel ratio 1, Material 3 light theme. The 1× capture uses English
(United States); Save and Discard keep their existing horizontal AppBar row
because their measured labels and button chrome fit. The supplemental 2× capture
uses German (`de-DE`); Save and Discard move below the title when their measured
width no longer fits, and both localized labels remain complete and operable.
Neither capture has a focused control or an open keyboard. The in-memory MCP
fixture uses an `example.invalid` endpoint and makes no provider or network
request.

- [320 × 640, en-US, 1× text](mcp-edit-en-320x640-scale1-light.png)
- [320 × 640, de-DE, 2× text](mcp-edit-de-320x640-scale2-light.png)

Before the fix, the focused 320 × 640 German widget run produced horizontal
RenderFlex overflows of 94 px at 1× and 298 px at 2×. The regression test now
checks those narrow states, the original horizontal action row when measured
text and button chrome fit (wide 1×), both action bounds, native field focus
and keyboard visibility, and Discard returning to read-only mode. Run it with:

```sh
flutter test --reporter expanded --plain-name \
  'MCP edit actions fit a narrow 2x text layout' \
  tests/widgets/mcp_settings_test.dart
```

The production capture is reproducible with
`python3 tool/qa/capture_vertical_mcp_appbar_scale.py`.
