# Chat file picker header and tabs at large text scale

The screenshots show the production `showAppFilePickerDialog` route with one
safe local text-file fixture selected. No account data, network request, or
file operation is used. `DPR` is the device-pixel ratio; viewport values are
logical pixels.

| State | Locale | Viewport | DPR | Text scale | Theme | Capture |
|---|---|---:|---:|---:|---|---|
| Before | en-US | 320 × 640 | 1 | 3× | Light | [Before fix](chat-file-picker-en-320x640-scale3-before.png) |
| After | en-US | 430 × 932 | 1 | 1× | Light | [Fitting layout](chat-file-picker-en-430x932-scale1-light.png) |
| After | en-US | 320 × 640 | 1 | 3× | Light | [Narrow layout](chat-file-picker-en-320x640-scale3-light.png) |
| After | en-US | 320 × 640 | 1 | 3× | Dark | [Dark theme](chat-file-picker-en-320x640-scale3-dark.png) |

At 1×, the original inline AppBar actions and icon tab layout remain in place.
At 3× on a narrow viewport, the clear action gets its own row and the four tabs
reflow to a text-first two-column layout. The full tab labels fit without
motion; the selected tab keeps its primary-color underline. The production
route test checks all four labels and their semantics, taps each tab, clears
the selection, and checks that the layout reports no rendering exception.
