# Narrow reasoning parameter header

The production `LlmModelConfigPage` was captured in Chromium at 320 × 640 CSS
pixels, device scale factor 1, French (`fr-FR`), default 1× text scale, and the
blue-seeded Material 3 light theme. No control is focused and the keyboard is
closed. The in-memory fixture includes a model-owned parameter and a provider
inherited parameter; it makes no provider request and writes no user data.

`reasoning-param-header-fr-320x640-1x-light.png` shows the inherited parameter's
name field on its own line, with the type and reset controls below it. The full
editable name remains visible inside the card, and the inherited parameter has
no delete action.

The regression is owned by `tests/pages/settings/llm_model_config_reasoning_header_test.dart`.
It checks French at 320 × 640/1× and German at 320 × 640/1.8×, verifies the
field/control reflow and inherited delete rule, confirms the original inline
header layout at 600 px, edits the native field while focused, resets it, and
reorders model-owned parameter cards by their handles. Its functional suite and
CI group are both `chat-ai-ui`.

Focused verification command:

```sh
flutter test --no-pub tests/pages/settings/llm_model_config_reasoning_header_test.dart --reporter expanded
```

The production capture fixture and script are
`tools/qa/vertical_reasoning_param_header_capture.dart` and
`tools/qa/capture_vertical_reasoning_param_header.py`.
