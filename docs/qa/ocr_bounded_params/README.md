# Bounded OCR custom parameter labels

The screenshot and motion preview use the production `OcrModelConfigPage` with a representative OCR model and a JSON custom parameter. Chromium renders the page at 320 × 640 logical pixels, device pixel ratio 1, German locale, light theme, and default text scale. The viewport is scrolled to show the custom-parameters heading/action, the name field beside the fixed type selector and delete action, and the default-value field.

- `ocr-custom-parameters-de-320x640-1x.png` is the production page at the narrow viewport.
- `parameter-label-reveal.webm` is a playable capture of the same rendered page showing the clipped heading and field labels after the initial stationary interval.
- `tests/pages/settings/ocr_model_config_constrained_text_test.dart` exercises the production page at that viewport, including an empty name becoming filled, focused/unfocused field labels, JSON validation feedback, native type selection, and selection of an existing option after changing away from JSON.

The capture harness mounts the production page directly with `ModelConfig` and `CustomParam`; it does not replace the page or its parameter controls. Its behavior is local and does not call a provider.
