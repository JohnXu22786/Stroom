# Bounded LLM custom parameter labels

These captures show the production `LlmModelConfigPage` with a JSON custom parameter in German (`de-DE`), rendered in Chromium at 320 × 640 CSS pixels, device scale factor 1, and default text scale. The screenshot includes the custom-parameters heading and action, name field beside its type and delete controls, and the default-value field.

- `llm-custom-parameters-de-320x640-1x.png` is the production page at the narrow viewport.
- `parameter-label-reveal.webm` is a playable preview of the same page, showing the bounded heading and field labels while the native editable fields remain in place.
- `tests/pages/settings/llm_model_config_bounded_params_test.dart` exercises localized labels at 320 × 640 with normal and enlarged text, and checks focus, editing, and JSON validation.

The capture harness mounts the production page directly with `ModelConfig` and `CustomParam`; it makes no provider requests.
