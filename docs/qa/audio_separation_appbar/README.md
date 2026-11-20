# Audio separation AppBar clear action

The captures use the production `AudioSeparationPage` with one local retry video in French at a 320 × 640 CSS viewport.

- [1× screenshot](fr-320x640-1x.png) and [playable 1× preview](fr-320x640-1x-preview.webm): the long localized page title scrolls within its centered toolbar area; the `Effacer` action remains fully visible and stationary.
- [3× screenshot](fr-320x640-3x.png) and [playable 3× preview](fr-320x640-3x-preview.webm): same page and CSS viewport at device pixel ratio (DPR) 3 (960 × 1920 physical pixels). This is a DPR capture, not a 3× text-scale capture; the clear action stays inside the AppBar.

The widget test also covers **text scale 3× at DPR 1**. With a selected retry video, the clear action stays within its 64–120 px slot and the page has no layout exception. The pre-fix action measured 282.6 logical px. The same test taps `Leeren`; after clearing, the empty page reports a separate `RenderFlex overflowed by 322 pixels on the bottom.` This post-clear full-page overflow is intentionally asserted and printed so it is not mistaken for an AppBar failure; it is a follow-up for the page's bottom layout.

Reproduce that diagnostic with:

```sh
flutter test --no-pub tests/pages/content/audio_separation_appbar_test.dart --plain-name '3x text scale bounds AppBar action and exposes post-clear overflow' --reporter expanded
```

At that text scale the pre-fix clear button measured 282.6 logical px wide, exceeding the responsive slot.

The page uses only the local retry fixture. No provider requests are made.
