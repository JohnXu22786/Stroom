# Provider custom parameter field labels

These captures use the production `showProviderSettingsPanel` with one existing JSON custom parameter in a 320 × 640 logical pixel Chromium viewport at device scale 1, German locale and light theme. The `1x` image uses default text scale; the `1_8x` image and playable preview use 1.8× text scale. The provider configuration is an unsaved example and makes no network requests.

- `provider-params-de-320x640-1x-light.png` shows the actual custom-parameters tab at default text scale.
- `provider-params-de-320x640-1x-dark.png` shows the same panel and layout in dark theme.
- `provider-params-de-320x640-1_8x-light.png` shows the same production panel with enlarged text.
- `provider-param-label-reveal.webm` records the live panel at 1.8×. The name and JSON default-value labels reveal their full localized text inside the existing field slots.
- `tools/qa/provider_custom_params_capture.dart` is the temporary page entry point used to build the capture; `?scale=1` and `?scale=1.8` select the text scale.
- `tests/pages/settings/provider_custom_params_constrained_labels_test.dart` checks both field labels in the production parameter tab at 320 × 640 and 1.8× text scale. Existing provider panel tests continue to cover custom parameter editing, type/options, validation, and save behavior.

The parameter name and JSON text field remain native `TextFormField`s. Their editing, focus and validation paths are unchanged; only their bounded static labels now use measured `ConstrainedText` slots. Dynamic name and JSON validation messages wrap naturally.
