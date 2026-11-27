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
| After | de-DE | 320 × 640 | 1 | 3× | Light | [Longer German labels](chat-file-picker-de-DE-320x640-scale3-light.png) |
| After | de-DE | 320 × 640 | 1 | 3× | Light | [Clear label at full-text endpoint](chat-file-picker-de-DE-320x640-scale3-clear-end.png) |

The [German Clear reveal preview](chat-file-picker-de-DE-clear-reveal-320x640.webm)
uses the production route capture as its backdrop and animates the complete
Roboto label over the measured 312-pixel slot at 4 frames per second. It shows
the one-second still period, a continuous 24 logical px/s travel to the exact
endpoint, and the full label held there. The route regression separately
measures the real `ConstrainedText` widget, checks its exact endpoint, two-second
hold and reverse, and verifies reduced motion leaves the full label static
while retaining its complete semantics. The endpoint screenshot is a direct
production-route capture.

At 1×, the original inline AppBar actions and icon tab layout remain in place.
At 3× on a narrow viewport, the clear action gets its own row and the four tabs
reflow to a text-first two-column layout. The full tab labels fit without
motion; the selected tab keeps its primary-color underline. The production
route test checks all four labels and their semantics, taps each tab, clears
the selection, and checks that the layout reports no rendering exception. The
de-DE case also checks the full title and long Clear label in semantics; Clear
scrolls through the existing `ConstrainedText` behavior after its initial
still period. No localized label is shortened.
