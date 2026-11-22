# Browser cookie path at narrow widths

The screenshot and playable preview show the production `BrowserCookiesPage`
at 320 × 640 CSS px, device pixel ratio 1, English (`en-US`), the blue-seeded
light theme, and normal 1× text scale. No control is focused and there is no
software keyboard because this screen contains no editable input. A long cookie
path reveals horizontally within its bounded row slot; the cookie name, masked
value, and delete action remain visible.

- [Production screenshot](cookie-path-en-320x640-1x-light.png)
- [40-second playable path reveal](cookie-path-reveal-320x640-1x-light.webm), showing the full horizontal reveal cycle.

The capture uses a local synthetic cookie fixture with a fake session value and
a long path. It does not browse to a site, make external requests, or reveal
cookie values. The path and all fixture strings are test-only.

Reproduce from the repository root:

```sh
flutter build web --release --no-pub --target tool/qa/browser_cookie_path_capture.dart --output /tmp/stroom-browser-cookie-path-web --no-wasm-dry-run
python3 -m http.server 8879 --directory /tmp/stroom-browser-cookie-path-web
python3 tool/qa/capture_browser_cookie_path.py
```
