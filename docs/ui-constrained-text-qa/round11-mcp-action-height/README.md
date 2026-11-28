# MCP compact AppBar action height

These screenshots come from the production `showMcpServerConfigDialog` route, opened in a Chromium render of `tool/qa/mcp_action_height_capture.dart`. The fixture uses an in-memory empty provider configuration and opens the new server dialog in create mode; it makes no provider request and writes no configuration.

| Capture | Viewport (logical px) | DPR | Locale | Text scale | Theme | State |
| --- | ---: | ---: | --- | ---: | --- | --- |
| `mcp-actions-fr-320x320-scale4-light-save.png` | 320 × 320 | 1 | fr-FR | 4× | Light, Material 3 | New MCP configuration, create mode, initial scroll position with Save row visible |
| `mcp-actions-fr-320x320-scale4-light-discard.png` | 320 × 320 | 1 | fr-FR | 4× | Light, Material 3 | New MCP configuration, create mode, dialog scrolled to Discard row |
| `mcp-actions-fr-320x640-scale4-light.png` | 320 × 640 | 1 | fr-FR | 4× | Light, Material 3 | New MCP configuration, create mode |
| `mcp-actions-fr-320x640-scale4-dark.png` | 320 × 640 | 1 | fr-FR | 4× | Dark, Material 3 | New MCP configuration, create mode |
| `mcp-actions-en-240x640-scale1-light.png` | 240 × 640 | 1 | en-US | 1× | Light, Material 3 | New MCP configuration, create mode |

At 320 × 640, the dialog is 272 dp wide. Before the fix, both compact action slots were fixed at 72 dp; French labels wrapped to two lines and the label exceeded that slot. The production render now measures each compact row at 160 dp, with the complete “Enregistrer” and “Abandonner” labels visible. The 240 × 640 fitting English render measures both rows at the original 48 dp, with one-line labels.

At 320 × 320, the two 160 dp action rows plus the toolbar exceed the dialog's 272 dp height. The full dialog content uses one vertical scroll owner so the title, both complete action rows, and the form remain reachable. Gestures over the form can scroll back to either action. The two short-viewport screenshots show the initial Save row and the scrolled Discard row; the production capture verifies both action bounds are inside the viewport in their respective scroll positions.

The capture script enables Flutter Web semantics after opening the dialog and checks that both save and discard actions have visible bounds inside the viewport. The focused widget regressions verify the wrapped French label is inside its action slot and AppBar at 320 × 640, that the title and both actions can be reached in the short dialog, that scrolling in the form returns to the actions, and that the English fitting rows retain their original height. The existing regression also taps Save, and the short-dialog test taps Discard; both check for layout exceptions.

Recreate the captures from the repository root with:

```sh
python3 tools/qa/capture_mcp_action_height.py
```
