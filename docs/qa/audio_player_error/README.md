# Audio player failure state

These captures render the production `AudioPlayerErrorView` with a safe local fixture, English (United States), the light Material theme, a 320 × 640 logical-pixel viewport, device scale 1, and normal text scale. The fixture contains a long playback error and 40 diagnostic lines; it makes no provider request.

- `audio-error-top-320x640.png` shows the initial error and the beginning of the selectable diagnostic details.
- `audio-error-retry-320x640.png` shows the bottom of the diagnostics and the reachable Retry action after scrolling.

The focused Flutter widget test also verifies that the long failure state remains scrollable and that Retry invokes the caller's callback.
