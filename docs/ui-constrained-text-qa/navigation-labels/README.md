# Responsive navigation label QA

## Result

No navigation label was clipped by its text slot, so `lib/pages/home_page_navigation.dart` remains unchanged. German and Brazilian Portuguese labels in the portrait `NavigationBar` wrap naturally at narrow widths and remain fully readable. The `NavigationRail` expands to fit its longest label horizontally.

A separate Flutter debug layout diagnostic appears in a 500×300 landscape rail at 1.6× text scale: `NavigationRail` reports a 4 px bottom `RenderFlex` overflow. The measured label boxes still fit inside the rail: the rail box is 137×300 at (0, 0), and `Einstellungen` is at (8, 266), size 121×26, ending at y=292. Its `RenderParagraph` reports unconstrained width and `didExceedMaxLines=false`. Flutter's debug overflow stripe overlays the last label in that debug screenshot; it does not indicate that the text slot clips the label. At 500×340 and 1.6× the same label is fully visible without the diagnostic. This is a rail layout diagnostic, not a `ConstrainedText` candidate.

## Localized labels and portrait slot measurements

At a 320 px viewport width, the four equal bottom navigation destinations each receive an 80 px slot:

- German: `Startseite`, `Chat`, `Dateien`, `Einstellungen`. At 1.6×, `Einstellungen` wraps across two lines and all characters remain visible.
- Brazilian Portuguese: `Início`, `Conversa`, `Arquivos`, `Configurações`. At 1.6×, the longer labels wrap and all characters remain visible.

## Capture method

Captured the real production `HomePage` and Material `NavigationRail` / `NavigationBar` in Chromium. A temporary QA entrypoint wrapped `HomePage` in a Material 3 `MaterialApp`, used the production localizations and a no-op override for startup restoration, and set `MediaQuery.textScaler` from the URL. It was removed after capture. The app was launched with:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8766 -t lib/navigation_labels_qa_main.dart
```

Playwright used `/usr/bin/chromium`, device scale factor 1, and captured only after Flutter logged `Starting application from main method`. The `1_6` screenshot suffix means 1.6× text scale. The `bounds` capture is the measured 500×300 German rail before the temporary measurement entrypoint was removed.

## Screenshots

- [German bottom bar, 320×640, 1.6×](portrait-de-320x640-scale1_6.png)
- [Portuguese bottom bar, 320×640, 1.6×](portrait-pt-br-320x640-scale1_6.png)
- [German rail, 500×300, 1.0×](rail-de-500x300-scale1_0.png)
- [German rail, 500×300, 1.6×, debug diagnostic](rail-de-500x300-scale1_6.png)
- [German rail, 500×300, 1.6×, bounds capture](rail-de-500x300-scale1_6-bounds.png)
- [Portuguese rail, 500×300, 1.6×](rail-pt-br-500x300-scale1_6.png)
- [German rail, 500×340, 1.6×](rail-de-500x340-scale1_6.png)
- [Portuguese rail, 500×340, 1.6×](rail-pt-br-500x340-scale1_6.png)
