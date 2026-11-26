# ASR model selector layout

These captures render the production `AsrPage` with a configured ASR model.

- [Portuguese, 320 × 1200, 2.5× text scale, light theme](asr-model-selector-pt-BR-320x1200-scale2_5-light.png): the long label is constrained to its own row and the model selector moves below it with a usable width.
- [Portuguese, 320 × 1200, 2.5× text scale, dark theme](asr-model-selector-pt-BR-320x1200-scale2_5-dark.png): the same responsive layout in the dark theme.
- [Portuguese, 640 × 800, 1× text scale, light theme](asr-model-selector-pt-BR-640x800-scale1-light.png): the original compact single-row layout remains in place when the label and selector fit.

The captures are produced by `tests/pages/settings/asr_page_test.dart` using the normal Flutter widget-test renderer. The focused test also checks that the narrow layout has no rendering exception and that the fitting layout keeps the label and dropdown aligned on one row.
