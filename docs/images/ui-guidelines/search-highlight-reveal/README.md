# Message search snippet reveal QA

These are captures of the production `MessageSearchPage` and its actual result-row builder, rendered by a Flutter web release build in Chromium. The fixture seeds two local conversations, searches for `needle`, and shows both a clipped highlighted Chinese snippet and a fitting highlighted snippet.

- Screenshot: [search-highlight-reveal-320x640.png](search-highlight-reveal-320x640.png)
- Playable preview: [search-highlight-reveal-motion.webm](search-highlight-reveal-motion.webm)
- Viewport: 320 × 640 CSS logical pixels, device pixel ratio 1
- Locale and theme: zh_CN, Material light theme
- Text scale: 1.0
- Search state: `needle`; the first result has multiple wrapped lines beyond the two-line row slot, while the second result fits on one line
- Reduced motion: Chromium emulated `no-preference`; the capture-only app builder enables Flutter tickers and animations so the actual reveal can be recorded
- Renderer: Flutter 3.47.9 release web build in headless Chromium 154.0.8037.57

The release app was built with `flutter build web --release -t tool/search_capture/main.dart --no-wasm-dry-run`, served locally with `python3 -m http.server 8765 --directory build/web`, and captured with Playwright and ffmpeg using `tool/search_capture/capture_preview.py`. The selected build uses Flutter's JavaScript web output; its optional WebAssembly dry run is skipped because this project has an unrelated `dart:html` dependency in `get_thumbnail_video`.

The screenshot and video were inspected after capture. The video shows the same clipped result moving through its wrapped lines; the fitting snippet remains stationary. No browser runtime errors occurred.
