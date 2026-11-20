# Reasoning configuration field labels

The screenshot is a Chromium capture of the production `LlmModelConfigPage` at 320×640 logical pixels, DPR 1, French locale, and default 1× text scale. The toggle card is visible with its parameter name and adjacent enabled/disabled value fields; the effort card begins below it. The toggle and effort card headings remain on one line beside their controls. The playable preview shows clipped localized labels revealing their ends after the normal initial delay.

The browser fixture is `tools/qa/reasoning_config_capture.dart`. It uses a model with a `thinking.type` toggle (`enabled` / `disabled`), a `reasoning_effort` parameter, and a `budget_tokens` parameter. Start it with:

```sh
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 9867 -t tools/qa/reasoning_config_capture.dart
```

Scroll the page by about 460 logical pixels to bring the reasoning toggle and effort cards into view. The regression test `tests/pages/settings/llm_model_config_reasoning_field_labels_test.dart` uses the same model and viewport at 1× and 1.8× text scales; it edits a focused value field, dismisses the keyboard, then toggles the reasoning parameter.
