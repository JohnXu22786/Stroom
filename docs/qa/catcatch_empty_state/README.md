# CatCatch empty-state guidance scrolling

The captures show the production `CatCatchPage` empty state at 320 × 640 CSS pixels. They use French (`fr-FR`), Material 3 light and dark themes, and text scales of 1× and 3×. The 3× capture is scrolled to show the complete help text above the fixed bottom bar; the 1× captures show the centered composition when the copy fits. No motion is introduced.

- [Fitting copy, light theme, 1×](catcatch-empty-state-fr-320x640-1x-light.png)
- [Fitting copy, dark theme, 1×](catcatch-empty-state-fr-320x640-1x-dark.png)
- [Overflowing copy, scrolled, light theme, 3×](catcatch-empty-state-fr-320x640-3x-light-scrolled.png)

The regression coverage is in [`tests/pages/catcatch_empty_state_layout_test.dart`](../../../tests/pages/catcatch_empty_state_layout_test.dart). The Flutter Web entrypoint and Playwright capture script are [`tool/qa/catcatch_empty_state_capture.dart`](../../../tool/qa/catcatch_empty_state_capture.dart) and [`tool/qa/capture_catcatch_empty_state.py`](../../../tool/qa/capture_catcatch_empty_state.py).
