# File information labels

The production `showFileInfoPreviewDialog` screenshot is 320 × 640 CSS pixels
at device scale factor 1, French (`fr-FR`), Material 3 light theme, and 1× text
scale. A safe in-memory PDF fixture supplies the metadata; there is no account
data or network request. No control is focused and the software keyboard is
closed. The path label is clipped in its 40 dp slot in the still image. The
playable preview records the same dialog while the label reveals its complete
localized value using the shared one-second initial hold and endpoint pauses.

## Artifacts

- [Production dialog screenshot](file-info-dialog-fr-320x640-scale1-light.png)
- [Production dialog with responsive German Close action](file-info-close-de-320x640-scale1-light.png): 320 × 640 CSS pixels, DPR 1, `de-DE`, light theme, 1× text scale; no control is focused and the keyboard is closed.
- [Live French label reveal](file-info-label-reveal-fr-320x640.webm)

## Capture

Recreate the release Flutter Web fixture and capture with:

```sh
python3 tool/qa/capture_file_info_label.py
```

The capture entrypoint mounts the real file information dialog with local
fixture data. The script verifies the 320 × 640 screenshot dimensions and
checks for browser runtime errors.

## Validation map

- `tests/pages/chat/widgets/info_row_test.dart`: keeps complete file values
  naturally wrapped; verifies that a long French label uses a single line at
  1.5× text scale.
- `tests/pages/chat/dialogs/localized_dialogs_test.dart`: opens the actual
  production dialog at 320 × 640 in French, German, and Arabic, checks all
  metadata labels use the bounded shared widget, and verifies the full path is
  present.
