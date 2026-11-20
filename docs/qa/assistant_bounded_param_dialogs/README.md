# Bounded assistant custom parameter dialogs

The screenshot and WebM preview use the production add-parameter dialog from `showAddCustomParameterDialog`, mounted by `tests/qa/assistant_custom_parameter_dialog_capture.dart`. The fixture uses German localization, a light Material 3 theme, a 320 × 640 logical viewport, device-pixel ratio 1, and default text scale. The title is intentionally long enough to demonstrate the clipped-label reveal; the editable fields and type selector remain native controls.

- `add-dialog-de-320x640-1x.png` is the production dialog at that viewport and scale.
- `parameter-title-reveal.webm` shows the title's initial stationary interval and horizontal reveal.
- `tests/pages/assistant_custom_param_dialog_test.dart` exercises the production add/edit dialogs, JSON validation and round-trip, focused input, boolean type selection, save/cancel, narrow viewport, keyboard insets, and 1.8× text scale.
