# MCP compact AppBar action height

These screenshots come from the production `showMcpServerConfigDialog` route, opened in a Chromium render of `tool/qa/mcp_action_height_capture.dart`. The fixture uses an in-memory empty provider configuration and opens the new server dialog in create mode; it makes no provider request and writes no configuration.

| Capture | Viewport (logical px) | DPR | Locale | Text scale | Theme | State |
| --- | ---: | ---: | --- | ---: | --- | --- |
| `mcp-actions-fr-320x640-scale4-light.png` | 320 × 640 | 1 | fr-FR | 4× | Light, Material 3 | New MCP configuration, create mode |
| `mcp-actions-fr-320x640-scale4-dark.png` | 320 × 640 | 1 | fr-FR | 4× | Dark, Material 3 | New MCP configuration, create mode |
| `mcp-actions-en-240x640-scale1-light.png` | 240 × 640 | 1 | en-US | 1× | Light, Material 3 | New MCP configuration, create mode |

At 320 × 640, the dialog is 272 dp wide. Before the fix, both compact action slots were fixed at 72 dp; French labels wrapped to two lines and the label exceeded that slot. The production render now measures each compact row at 160 dp, with the complete “Enregistrer” and “Abandonner” labels visible. The 240 × 640 fitting English render measures both rows at the original 48 dp, with one-line labels.

The capture script enables Flutter Web semantics after opening the dialog and checks that both save and discard actions have visible bounds inside the viewport. The focused widget regression also verifies the wrapped French label is inside its action slot and AppBar, checks the fitting English total height, taps save to confirm the dialog remains usable, and checks for layout exceptions.

Recreate the captures from the repository root with:

```sh
python3 tools/qa/capture_mcp_action_height.py
```
