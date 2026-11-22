# Responsive navigation label QA

## Result

Bottom navigation uses one line per destination and the shared `ConstrainedText` reveal. A German `Einstellungen` label is actually clipped in its 80 dp destination at 320 dp viewport width and moves after the shared 1 second still period. Short labels stay still. The wide-layout `NavigationRail` remains Material's rail; it sizes to its label and keeps `Einstellungen` centered and stationary when it fits.

The bottom bar retains the Material 3 80 dp height, surface color, icon/indicator colors, tap feedback, selection semantics, and selection behavior. Flutter's public `NavigationDestination` only accepts a `String` and constructs its own `Text`, so it cannot host `ConstrainedText`; the bottom destination layout is implemented locally to preserve that Material appearance while supplying the shared clipped-label behavior. The rail still uses `NavigationRailDestination` directly.

## Current production capture

The capture below uses the real production `HomePage` at 320×640 CSS pixels and device pixel ratio 1. Locale is German (`de`), theme is light, text scale is 1.0, and the selected destination is Home. `Einstellungen` is the app's localized Settings label; no synthetic label text is used.

- [German bottom navigation, 320×640, scale 1.0](portrait-de-320x640-scale1_0.png)
- [Playable Brazilian Portuguese label reveal, WebM](navigation-label-reveal-pt-br-320x640.webm)

The WebM uses the production Brazilian Portuguese label `Configurações` so the movement is easy to see; it captures one complete reveal and reversal cycle at the same 320×640, 1x, light-theme settings. The focused widget test confirms the narrow German destination enters the clipped reveal path and retains the full semantic label. At a wide viewport, the rail label has no reveal clip and is centered.

## Capture method

Run the real app shell with the small QA entrypoint and capture it using Chromium/Playwright:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8877 -t tool/qa/navigation_labels_preview.dart --no-pub
python3 tool/qa/capture_navigation_labels.py
```

The entrypoint accepts `locale`, `scale`, `theme`, and `motion` query parameters. The capture script waits for Flutter's `Starting application from main method` console message, records browser page errors, and uses `/usr/bin/chromium` at DPR 1. The preview reproduces the production HomePage and its localizations; it does not replace the label with a test string. The screenshot page had no uncaught browser page errors; the production HomePage logs expected storage `Unsupported operation` messages in web builds because native persistence APIs are unavailable there.

## Earlier baseline captures

The `scale1_6` and rail-bound captures predate this one-line bottom-bar fix. They record the former Material `NavigationBar` behavior at larger text scales and are retained as historical evidence. The original 500×300 rail measurement showed that the Material rail expanded to 137 dp at 1.6× scale and gave `Einstellungen` 121 dp, so that fitting label remained static.
