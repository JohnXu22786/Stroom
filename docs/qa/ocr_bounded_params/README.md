# Bounded OCR custom parameter labels

The screenshot and motion preview use the production `OcrModelConfigPage` with a representative OCR model and a JSON custom parameter. Chromium renders the page at 320 × 640 logical pixels, device pixel ratio 1, German locale, light theme, and default text scale. The viewport is scrolled to show the request-size override input alongside the custom-parameters heading/action, name field, fixed type selector and delete action, and default-value field.

- `ocr-custom-parameters-de-320x640-1x.png` is the production page at the narrow viewport.
- `parameter-label-reveal.webm` is a playable capture of the same rendered page showing the request-size, section, and parameter field labels reveal clipped text after the initial stationary interval.
- `tests/pages/settings/ocr_model_config_constrained_text_test.dart` exercises the production page at that viewport, including the localized request-size label and native numeric keyboard/focus/suffix/validation; it also covers parameter-name clearing/refill, focused parameter labels, JSON validation feedback, native type selection, and selection of an existing option after changing away from JSON.

The capture harness mounts the production page directly with `ModelConfig` and `CustomParam`; it does not replace the page or its parameter controls. Its behavior is local and does not call a provider.
