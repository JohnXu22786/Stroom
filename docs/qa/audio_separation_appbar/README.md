# Audio separation AppBar clear action

The captures use the production `AudioSeparationPage` with one local retry video in French at a 320 × 640 CSS viewport.

- [1× screenshot](fr-320x640-1x.png) and [playable 1× preview](fr-320x640-1x-preview.webm): the long localized page title scrolls within its centered toolbar area; the `Effacer` action remains fully visible and stationary.
- [3× screenshot](fr-320x640-3x.png) and [playable 3× preview](fr-320x640-3x-preview.webm): same page and CSS viewport at device pixel ratio (DPR) 3 (960 × 1920 physical pixels). This is a DPR capture, not a 3× text-scale capture; the clear action stays inside the AppBar.
- [Cleared empty state at 1×](de-empty-320x640-1x.png): production page at 320 × 640 CSS pixels, DPR 1, after clearing the local German retry video.

The widget test also covers **text scale 3× at DPR 1**. With a selected retry video, the clear action stays within its 64–120 px slot and the page has no layout exception. The pre-fix action measured 282.6 logical px. Tapping `Leeren` exposes the empty state and its action in a vertically scrollable page, with no bottom overflow. The ordinary 1× layout keeps its bottom action in view.

Reproduce that diagnostic with:

```sh
flutter test --no-pub tests/pages/content/audio_separation_appbar_test.dart --plain-name '3x text scale keeps AppBar action and cleared page scrollable' --reporter expanded
```

At that text scale the pre-fix clear button measured 282.6 logical px wide, exceeding the responsive slot. The same viewport then overflowed by 322 logical px after clearing because the enlarged empty state, fixed source row, and bottom controls were siblings in a non-scrollable `Column`. Expanded-text empty states now place those regions in a scroll view; the selected-video and ordinary 1× layouts retain their prior structure.

The page uses only the local retry fixture. No provider requests are made.
