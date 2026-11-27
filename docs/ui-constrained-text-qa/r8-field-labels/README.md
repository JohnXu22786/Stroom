# Field hint and helper QA

These captures use the production Flutter widgets in `tool/qa/r8_field_labels_capture.dart`. The fixture supplies local data only. All scenarios use the German `de-DE` locale, a light Material 3 theme, and browser device pixel ratio 1. `scale` below is Flutter's logical text scale; viewport dimensions are CSS pixels and logical pixels at this DPR.

Static PNG captures enable reduced motion so the initial ellipsis is stable. The two WebM previews use normal motion and show the horizontal reveal on the language and folder hints. The save-preset explanation remains static prose and wraps naturally.

## Scenarios

| Capture | Viewport | Text scale | State |
| --- | ---: | ---: | --- |
| `after/language-search-de-320x640-scale2.png` | 320×640 | 2× | Theme/display page scrolled to the language search field; localized hint is clipped to the field width. |
| `after/language-search-de-800x900-scale1.png` | 800×900 | 1× | Language search field and fitting hint. |
| `after/folder-hints-de-360x800-scale2.png` | 360×800 | 2× | Folder picker with the caller-provided chat filename hint and the create-folder input open; both hints are clipped. |
| `after/folder-hints-de-800x900-scale1.png` | 800×900 | 1× | Same picker state with caller-provided filename hint and default folder hint fully fitting. |
| `after/save-preset-helper-de-320x640-scale1.png` | 320×640 | 1× | Batch rename save-preset dialog; complete German helper wraps across lines. |
| `after/save-preset-helper-de-900x720-scale1.png` | 900×720 | 1× | Same save-preset dialog at a wide viewport; helper wraps naturally and remains untruncated. |
| `after/language-search-de-320x640-scale2.webm` | 320×640 | 2× | Nine-second playable language-search hint reveal. |
| `after/folder-hints-de-360x800-scale2.webm` | 360×800 | 2× | Nine-second playable folder input hint reveal. |

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

The static capture script records all six PNG scenarios and checks that screenshots are nonblank, use DPR 1, and have no browser page errors. The motion script captures browser frames and encodes the playable previews with `/usr/bin/ffmpeg`.
