# Field hint and helper QA

These captures use the production Flutter widgets in `tool/qa/r8_field_labels_capture.dart`. The fixture supplies local data only. All scenarios use the German `de-DE` locale, a light Material 3 theme, and browser device pixel ratio 1. `scale` below is Flutter's logical text scale; viewport dimensions are CSS pixels and logical pixels at this DPR.

Static PNG captures enable reduced motion so the initial ellipsis is stable. The three WebM previews show one full horizontal reveal cycle each: language search, the caller-provided folder filename hint, and the new-folder name hint. They end with the same reduced-motion ellipsis state shown in the static captures. The save-preset explanation remains static prose and wraps naturally.

## Scenarios

| Capture | Viewport | Text scale | State |
| --- | ---: | ---: | --- |
| `after/language-search-de-320x640-scale2.png` | 320×640 | 2× | Theme/display page scrolled to the language search field; localized hint is clipped to the field width. |
| `after/language-search-de-800x900-scale1.png` | 800×900 | 1× | Language search field and fitting hint. |
| `after/folder-hints-de-360x800-scale2.png` | 360×800 | 2× | Folder picker with the caller-provided chat filename hint and the create-folder input open; both hints are clipped. |
| `after/folder-hints-de-800x900-scale1.png` | 800×900 | 1× | Same picker state with caller-provided filename hint and default folder hint fully fitting. |
| `after/save-preset-helper-de-320x640-scale1.png` | 320×640 | 1× | Batch rename save-preset dialog; complete German helper wraps across lines. |
| `after/save-preset-helper-de-900x720-scale1.png` | 900×720 | 1× | Same save-preset dialog at a wide viewport; helper wraps naturally and remains untruncated. |
| `after/language-search-de-320x640-scale2.webm` | 320×640 | 2× | Playable search hint round trip at 3.4 fps. Chromium measured 64.07 dp of horizontal overflow, or 2.67 seconds each way at 24 dp/second. Capture wall time: 10.8 seconds; ffprobe duration: 11.765 seconds. The first and last frames both show `Sprachen s…`. |
| `after/folder-file-name-de-360x800-scale2.webm` | 360×800 | 2× | Filename-only folder picker state, so the preview captures the full caller-provided hint round trip without the shorter folder hint cycling again. Chromium measured 610.87 dp of overflow, or 25.45 seconds each way at 24 dp/second. Capture wall time: 58.9 seconds; ffprobe duration: 57.353 seconds. The first and last frames both show `Gib einen Dat…`. |
| `after/folder-folder-name-de-360x800-scale2.webm` | 360×800 | 2× | New-folder-only hint state, with the filename field prefilled so it does not animate. The preview includes the full 213.5 dp hint round trip (8.9 seconds each way) and holds. Capture wall time: 24.5 seconds; ffprobe duration: 24.412 seconds. The first and last frames both show `Ordner…`. |

## Reproduce

From the repository root, build and serve the real Flutter web fixture:

```sh
flutter build web --release --no-pub \
  --target tool/qa/r8_field_labels_capture.dart \
  --output /tmp/r8-field-labels-web --no-wasm-dry-run
python3 -m http.server 8878 --bind 127.0.0.1 \
  --directory /tmp/r8-field-labels-web
```

In another terminal, run the capture scripts:

```sh
python3 tool/qa/capture_r8_field_labels.py
python3 tool/qa/capture_r8_field_labels_motion.py
```

The static capture script records all six PNG scenarios and checks that screenshots are nonblank, use DPR 1, and have no browser page errors. The motion script holds reduced motion while setting up each full affected state and captures the stationary ellipsis for at least one second. It then enables motion for a complete reveal, endpoint hold, and return at the production speed. The final three frames restore reduced motion so the ending exactly matches the static leading ellipsis. It encodes the previews at 3.4 fps to match the measured browser-frame interval with `/usr/bin/ffmpeg`. Capture wall time and ffprobe duration are listed for each preview.
