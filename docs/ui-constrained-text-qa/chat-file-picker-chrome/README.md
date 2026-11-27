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
| Browser route | de-DE | 320 × 640 | 1 | 3× | Light | [Clear head/start](chat-file-picker-de-DE-320x640-scale3-clear-head-browser.png) · [tail endpoint](chat-file-picker-de-DE-320x640-scale3-clear-tail-browser.png) · [return to head](chat-file-picker-de-DE-320x640-scale3-clear-return-browser.png) |

The [German Clear reveal preview](chat-file-picker-de-DE-clear-reveal-320x640.webm)
is a direct Playwright recording of the production `ChatFilePickerDialog` route
in Flutter Web/Chromium, with a selected local text fixture. It is 13.33 seconds
long at 6 fps (capture timestamps 0 through 13.17 seconds) and shows the
one-second initial still, the 24 logical px/s travel to the tail endpoint, its
two-second hold, the return travel, and the two-second head hold. In the latest
capture the first completed screenshot was 0.386 seconds after first render;
the forward and return travels have 25 real samples each, with maximum gaps of
one and zero frames. The full label remains in route semantics throughout.
The Chromium recorder starts sampling at the fixture-selection click and uses
a `MutationObserver` timestamp for the first rendered Clear semantics node to
align the video timeline. It requires an actual screenshot request after first
render to complete during the one-second still and checks sample coverage in
both travel directions before publishing the staged clip and endpoint frames.
The regression measures 410.003 logical px of label text in a 312 logical px
slot and checks the exact endpoint, hold and reverse. With reduced motion, the
visual label stays stationary and uses a single-line ellipsis in that slot;
the complete localized label remains available in route semantics. The three
browser screenshots are direct route captures.

At 1×, the original inline AppBar actions and icon tab layout remain in place.
At 3× on a narrow viewport, the clear action gets its own row and the four tabs
reflow to a text-first two-column layout. The full tab labels fit without
motion; the selected tab keeps its primary-color underline. The production
route test checks all four labels and their semantics, verifies tab selection
and the active page after each tap, clears the selection, and checks that the
layout reports no rendering exception. Short 568 × 320 and 568 × 401 landscape
cases check that the selected file list, Clear action, preview and confirmation
remain reachable with a vertical drag and that horizontal swipes from a row,
the empty state, and unused active-tab viewport space still change the tab;
preview and confirmation interactions remain outside the swipe region. A long text folder verifies that its row is hit-testable after
scrolling, selection count changes on tap, and the scroll extent follows the
active folder's natural rows before contracting after switching to an empty
tab. Only the active tab's page is built in this compact scroll layout, with
rows created lazily as the user scrolls; changing tabs returns the shared
scroll position to the top. The
de-DE case also checks the full title and long Clear label in semantics; Clear
scrolls through the existing `ConstrainedText` behavior after its initial
still period. No localized label is shortened.
