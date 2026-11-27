# Search panel placeholder hint

These captures use the production `SearchPanel` in a modal bottom sheet with an empty local conversation list. The German view at 320 × 640 CSS pixels and 2× text scale clips the long localized placeholder before it reveals inside the original field. The English comparison at 390 × 844 and 1× text scale fits and stays stationary. A dark-theme reduced-motion capture shows the same clipped hint without animation.

- `search-panel-hint-de-320x640-scale2-light.png` — clipped localized hint in the narrow field.
- `search-panel-hint-reveal-de-320x640-scale2-light.webm` — 15-second real-time preview covering the initial still period, full reveal, both endpoint holds, and return to the clipped starting position.
- `search-panel-hint-en-390x844-scale1-light.png` — fitting comparison; the hint stays in its original position.
- `search-panel-hint-de-320x640-scale2-dark-reduced-motion.png` — dark theme with system reduced motion enabled.

Regenerate the production captures with:

```sh
python3 tool/qa/search_panel_hint_capture.py
```

The focused regression test is:

```sh
flutter test --no-pub --reporter expanded tests/widgets/search_panel_hint_test.dart
```
