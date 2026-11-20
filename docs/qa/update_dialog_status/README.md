# Update dialog status labels

Both the completed-download and installing status rows use flexible one-line `ConstrainedText` slots. Labels that fit keep their existing position; clipped values reveal the remaining text. The status icon, dialog actions and update operations are unchanged.

All captures show the production `UpdateDialog` with a local completed-update `UpdateState`; no update request is made. Each image is 320 × 640 pixels at device-pixel ratio 1. The text multiplier is stated separately below:

- [Completed status, system text scale 1.0](german-complete-320x640-dpr1-text1_0.png): the German label fits and remains stationary. Captured in the Flutter widget test renderer with Roboto and Material Icons loaded.
- [Completed status, system text scale 1.8](german-complete-320x640-dpr1-text1_8.png): Flutter Web capture at the trailing reveal endpoint, where the label's final characters are visible.
- [Playable overflow reveal, system text scale 1.8](german-status-overflow-dpr1-text1_8.webm): a 4.5-second, 10 fps recording of the real dialog as the German label moves across its clipped slot. Frames are 320 × 640 at device-pixel ratio 1.

Widget tests also measure both completed and installing labels at 320 × 640 and text scale 1.8 in light and dark themes, confirming that each label exceeds its finite slot without a layout exception.
