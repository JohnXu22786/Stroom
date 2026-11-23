# Backup restore confirmation

The screenshots show the production `BackupRestorePage` restore confirmation
at 320 × 640 CSS pixels, device pixel ratio 1, German (`de-DE`), Material 3
light theme, and normal 1× text scale. The normal page defaults select all nine
restore categories, producing a safe in-memory fixture. The first image shows
the beginning of the confirmation content; the second shows its lower
decision-critical details after scrolling. Both choices remain outside the
scrollable content and available. No control is focused, the software keyboard
is closed, and the confirmation is never accepted, so no file is picked and no
data is restored. No account data or network request is used.

- [Confirmation at the start of its content](restore-confirm-de-320x640-scale1-light.png)
- [Confirmation scrolled to the restart notice](restore-confirm-de-320x640-scale1-light-scrolled.png)
- [Capture entrypoint](../../../../tool/qa/vertical_restore_confirm_capture.dart)
- [Capture script](../../../../tool/qa/capture_vertical_restore_confirm.py)

Recreate with `python3 tool/qa/capture_vertical_restore_confirm.py`. The script
builds the release Flutter Web fixture when needed and captures both states in
Chromium.

The regression test is in `tests/pages/backup_restore_page_test.dart` and
checks localized multiple-category warnings at 320 × 640 and 1.7× text scale,
scroll access to the restart notice, and both cancel and confirm choices. The
confirm case uses a file picker that cancels immediately; it cannot restore
data.
