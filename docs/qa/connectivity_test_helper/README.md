# Connectivity test JSON helper wrapping

The screenshot shows the production `ConnectivityTestDialog` in German at 320 × 640 CSS pixels and 1× device scale, rendered in Chromium. The JSON helper wraps over multiple lines and remains complete; the text field is still the native multiline input. The local save and run callbacks make no provider or network request.

`tests/widgets/connectivity_test_dialog_test.dart` checks the complete helper in every supported locale at 320 × 640 and verifies that JSON editing, caret placement, and multiline keyboard state still work with a keyboard inset.

- [Rendered production dialog, 320 × 640, 1×](german-320x640-1x.png)
