# Search result metadata bounds

The captures use the production `SearchPanel` in its production modal-sheet
layout, with one synthetic local conversation containing two messages.

- `search-metadata-zh-320x640-scale1-light.png` shows the result at 320 × 640,
  device scale 1, Simplified Chinese (China), light theme, and 1× text. The date,
  message icon and count stay in their original inline alignment.
- `search-metadata-reveal-320x640-scale2_5.webm` is a crop of the result row at
  2.5× text scale. The date reveals only within its available width and the
  message count wraps below it when the two no longer fit on one line.

The search field contains `Demo` and remains focused in both captures.
Desktop Chromium does not display a software keyboard. The build used only a
local fixture and static local Flutter assets; no application API request was
made. The release Flutter Web build was inspected in headless Chromium and
reported no page errors.

Reproduce the capture with:

```sh
flutter build web --release --no-pub --target tool/qa/search_panel_metadata_capture.dart --output /tmp/stroom-search-metadata-web --no-wasm-dry-run
python3 -m http.server 8878 --directory /tmp/stroom-search-metadata-web
python3 tool/qa/capture_search_panel_metadata.py
```
