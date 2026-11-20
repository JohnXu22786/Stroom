# Chat model chip constrained label QA

These captures show the production `ModelNameChip` rendered in a temporary Flutter Web harness and cropped to the component. The harness uses the real widget and `ConstrainedText`, with the same 292 dp maximum width used by the narrow composer settings row at 320 × 640 CSS px, DPR 1, and 1× text scale. Model/provider display names are source values and are intentionally locale-independent.

- `model-chip-320x640-light.png` and `model-chip-320x640-dark.png`: light and dark theme captures. The complete model/provider value is longer than the available width and moves within the chip; the icon and chip geometry remain fixed.
- `model-chip-motion-320x640-crop.webm`: an 8 second playable capture showing the moving label.

The widget regression test also covers a fitting label (which remains stationary), full semantics, and the narrow clipped state without layout exceptions. Captures were made with Flutter 3.47.9 and Chromium.
