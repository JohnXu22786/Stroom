# File manager folder delete confirmation

The screenshots show the production `FileManagerView` delete confirmation at
320 × 640 CSS pixels, device pixel ratio 1, English (United States), the light
Material 3 theme, and 1× text scale. A local fixture provides a 40-level folder
path; the delete callback is a no-op. The first image shows the start of the
path with Cancel and Delete available. The second shows the scrolled path end
with both actions still available. No control is focused, the keyboard is
closed, and no account data or network request is used.

- [Confirmation at the start of the path](folder-delete-confirm-en-320x640-1x-light.png)
- [Confirmation scrolled to the path end](folder-delete-confirm-en-320x640-1x-light-scrolled.png)
- [Capture entrypoint](../../../../tool/qa/vertical_folder_delete_confirm_capture.dart)
- [Capture script](../../../../tool/qa/capture_vertical_folder_delete_confirm.py)

Recreate with `python3 tool/qa/capture_vertical_folder_delete_confirm.py`. The
script builds the release Flutter Web fixture when needed and captures both
states in Chromium.

The focused regression test is owned by
`tests/widgets/file_manager_test.dart` under
`FileManagerView batch operations`:
`long nested folder delete confirmation scrolls and preserves actions`. It
checks the long nested path at 320 × 640 and 2× text scale, English and French
localizations, scrolling, and both cancel and confirm callbacks.
