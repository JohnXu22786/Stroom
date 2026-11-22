# Provider basic input label captures

These captures use the production `showProviderSettingsPanel` component in a 320 × 640 Flutter Web viewport at device scale 1. The test panel is an unsaved French LLM provider configuration with example-only values.

## Capture states

- `provider-settings-fr-320x640-scale1-light.png`: French basic tab at the default text scale in the light theme.
- `provider-settings-fr-320x640-scale2-dark.png`: the same tab at 2× text scale in the dark theme. The labels and selected endpoint value move only where their measured one-line slots clip them.
- `provider-input-label-motion.webm`: live 2× text-scale capture showing the provider name, URL, key, and endpoint labels revealing their full French strings inside the fields. It begins on the test harness launch screen, then opens the real panel.

`provider_settings_panel_constrained_labels_test.dart` lays out the provider and OCR field labels plus endpoint options at 320 × 640 and 2× text scale for every supported locale. It also opens the endpoint menu, checks the bounded option labels, and edits the provider name to verify the input remains editable.
