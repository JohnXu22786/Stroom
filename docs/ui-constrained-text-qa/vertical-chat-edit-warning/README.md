# Chat edit warning

## Production composer at 1×

The production `ChatComposerWidget` capture shows the complete French data-loss warning wrapping beside its warning icon and close action, with the editor input still visible below it. In very short viewports where warning text itself must scroll, auto-hide pauses until the text fits again; the close action stays visible. It was rendered at 320 × 640 CSS pixels, DPR 1, `fr-FR`, Material 3 light theme, and 1× text scale. No control is focused and the software keyboard is closed.

- [Composer screenshot](edit-warning-fr-320x640-scale1-light.png)
- [Reproduce the capture](../../../tool/qa/capture_vertical_chat_edit_warning.py)
- [Composer fixture app](../../../tool/qa/vertical_chat_edit_warning_capture.dart)

## Production ChatPage with keyboard inset at 1.5×

The second capture uses the real `ChatPage`, an in-memory conversation, and a dummy provider. It is 320 × 640 CSS pixels, DPR 1, `fr-FR`, Material 3 light theme, 1.5× text scale, with the edit field focused and a 260dp bottom inset reserved for the software keyboard. Flutter Web does not draw a native keyboard in the screenshot; the inset reproduces the resulting short-height layout. The message list is temporarily hidden during short-height editing so the warning and composer controls remain available; dismissing the keyboard restores the conversation list and preserves the edit draft (covered by `chat_page_edit_warning_test.dart`).

- [ChatPage keyboard-state screenshot](chat-page-edit-warning-fr-320x640-scale1.5-keyboard.png)
- [Reproduce the capture](../../../tool/qa/capture_vertical_chat_page_edit_warning_keyboard.py)
- [ChatPage fixture app](../../../tool/qa/vertical_chat_page_edit_warning_keyboard_capture.dart)

Both fixtures use local messages and make no account or provider/network requests. During Web startup the `flutter_chat_ui` IndexedDB `CrossCache` may report a disposal race while opening its cache; the screenshot is captured after ChatPage initialization and edit entry.
