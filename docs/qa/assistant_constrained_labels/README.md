# Assistant editor constrained field labels

The capture uses the production `AssistantSelectionPage` and its create-assistant dialog. Chromium renders it at 320 × 640 logical pixels, 1× device scale, German locale, light theme, and normal text scale. The new-assistant name field has autofocus and focus; Chromium does not show a software keyboard. The entered value is empty, and no provider request is made.

- `assistant-editor-de-320x640-1x-light-focused.png` shows the focused name field and clipped German name and description labels.
- [Play the clipped field-label reveal](clipped-assistant-field-labels-preview.webm). Both clipped labels remain still initially, then move within their field slots; the multiline prompt remains editable and wraps normally.
- `tool/qa/assistant_editor_capture.dart` mounts the production assistant selection page for local reproduction (`?locale=de`, optionally `&theme=dark`).
- `tests/pages/assistant_pages_test.dart` checks the production editor labels and native name-field focus and typing. `tests/pages/assistant/assistant_remote_source_dialog_test.dart` checks the production URL label and native URL typing. `tests/widgets/constrained_text_test.dart` covers fitting, clipped, and focused-field behavior.
