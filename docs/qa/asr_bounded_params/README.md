# Bounded ASR custom parameter labels

The screenshot and motion preview use the production `AsrModelConfigPage` with a representative existing model parameter, rendered in Chromium at 320 × 640 logical pixels, device pixel ratio 1, German locale, light theme, and default text scale. The parameter is named `reasoning_effort`, uses JSON type, and contains a short formatted JSON object. The screenshot shows the custom-parameters heading/action, the name field beside the fixed type selector and delete action, and the default-value field.

- `asr-custom-parameters-de-320x640-1x.png` is the production page at the narrow viewport.
- `parameter-label-reveal.webm` is a playable capture of the same rendered page; it shows the heading and field label reveal clipped text after the initial stationary interval.
- `tests/pages/settings/asr_model_config_constrained_text_test.dart` exercises the same page at that viewport with an editable custom parameter, including focus, text entry, JSON validation feedback, and type selection.

The capture harness mounts the production page directly with `ModelConfig` and `CustomParam`; it does not replace the page or its parameter controls.
