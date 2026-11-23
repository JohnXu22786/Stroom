# Audio picker metadata

These captures show the production `showMediaPickerDialog` and its list row,
using the same `buildAudioTextPickerSubtitle` function as `AudioPlayerPage`.
The fixture keeps its record and file bytes in memory; it makes no account,
storage, or provider request.

- Narrow: 320 × 640 logical pixels, 1× device scale, German (`de-DE`), light
  theme, 1× text scale. Metadata naturally wraps onto two lines. No control is
  focused and the keyboard is closed.
- Wide: 1200 × 800 logical pixels, 1× device scale, German (`de-DE`), light
  theme, 1× text scale. Both complete metadata values fit on one line. No
  control is focused and the keyboard is closed.

The production picker retains its ordinary file-row layout and selection
behavior. The capture fixture lives at
[`tool/qa/vertical_audio_picker_metadata_capture.dart`](../../../tool/qa/vertical_audio_picker_metadata_capture.dart);
rebuild it with this command, then run the capture script. The script serves
the build on port 8894 automatically.

```sh
flutter build web --release --no-pub \
  --target tool/qa/vertical_audio_picker_metadata_capture.dart \
  --output /workspace/.cloud-profile-state/vertical_audio_picker_metadata/web-build \
  --no-wasm-dry-run
```

Functional suite owner: `tests/widgets/app_media_picker_dialog_test.dart` owns
the picker layout regression. The unique case, `wraps long metadata subtitles
at narrow widths`, checks that complete long metadata reflows without layout
exceptions at 320 × 640 and returns to one line at 1200 × 800.

Run `python3 tool/qa/capture_vertical_audio_picker_metadata.py` to capture both
screenshots.
