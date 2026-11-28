# Chat search field height

These captures render the production `ChatPage` search row in a safe local
fixture with no provider request, account data, or persisted conversation.
The native search field is focused, and the software keyboard is not shown.

| Capture | Viewport | Locale | Text scale | Theme | Evidence |
|---|---:|---|---:|---|---|
| `chat-search-en-800x640-scale1-light.png` | 800 × 640 logical px | en-US | 1× | Light | The full hint fits in the search row, and the field keeps its original 32 dp height. |
| `chat-search-fr-320x640-scale2-light.png` | 320 × 640 logical px | fr-FR | 2× | Light | The long hint clips during its initial still interval; the field grows to fit scaled native text while search navigation and close controls remain visible. The hint remains a measured `ConstrainedText` and uses its existing horizontal reveal path. |
| `chat-search-fr-320x640-scale2-dark.png` | 320 × 640 logical px | fr-FR | 2× | Dark | Confirms the expanded field, clipped initial hint, and reachable search controls in dark theme. |

The focused regression test also enters text after the scaled capture to verify
that editing still uses the native `TextField` behavior.
