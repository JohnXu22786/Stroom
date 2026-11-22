# Home content label QA

## Result

The HomePage recent-task heading and its “view all” action shared a finite row. At 320 CSS px with German text at 2× scale, their natural widths overflowed the row by 103 px. Both now use `ConstrainedText.home` within finite slots. The heading stays at the leading edge and the action at the trailing edge, including right-to-left layout. Complete labels stay still when they fit and reveal only when clipped.

The module tiles also overflowed their fixed aspect-ratio height by 29 px at this narrow, large-scale state. Their original aspect-ratio height is now a minimum: normal-scale cards retain the same proportion, and cards grow when scaled text needs more vertical room. Card typography and text remain unchanged.

Task-flow title and empty-state detail continue wrapping naturally and remain reachable by page scroll. The existing 8 × 8 status dots stay horizontally centered with their counts.

## Visual validation

All captures use the production `HomePage` in a temporary Flutter Web entrypoint, Flutter 3.47.9 / Dart 3.13.7, Chromium 154.0.8037.57, device scale factor 1, the app's blue-seeded Material 3 fallback theme, empty task-flow state, zero recent-task counts, and all seven module cards.

The matched overflow comparisons use German (`de-DE`), 320 × 900 CSS px, 2× text scale, light theme. The baseline is `origin/main` at `198ec760`; the after capture is this worktree. The header comparison places the same full header location side by side. The module comparison aligns crops to the first module-card row from each capture (baseline row top at y=328; after row top at y=212) so the card heights and contents can be compared directly.

| Evidence | Capture |
|---|---|
| Recent-task header, before / after | [320 × 900, de-DE, 2×, light](de_320x900_scale2_light_comparison.png) |
| Module cards, before / after | [320 × 900, de-DE, 2×, light](de_320x900_scale2_light_modules_comparison.png) |
| Normal-scale fit in the real app | [390 × 900, English, 1×, light](en_390x900_scale1_light_fit.png) |
| Header reveal motion | [Playable 35.75-second Chromium capture](home_header_reveal.webm) |

The motion preview shows the production welcome heading after its 1-second initial hold, its travel to both exact endpoints at 24 logical px/s, and the 2-second endpoint pauses. `tests/widgets/constrained_text_test.dart` confirms there is no movement through 999 ms, checks the first 250 ms of travel at about 6 px, and verifies the exact horizontal endpoint and 2-second endpoint wait. The shared widget defaults to 24 logical px/s.

## Regression coverage

`tests/pages/home_page_short_screen_test.dart` checks the module-grid page scroll, status-dot alignment and size, natural wrapping, finite header labels at English normal scale and Portuguese 1.7× scale, German 2× layout, card growth, and right-to-left trailing alignment.

Validation completed:

- `flutter test tests/pages/home_page_short_screen_test.dart` — passed.
- `flutter test tests/widgets/constrained_text_test.dart --plain-name 'moves clipped labels after the initial delay'` — passed.
- `flutter test tests/widgets/constrained_text_test.dart --plain-name 'shows the trailing text at the horizontal endpoint'` — passed.
- `dart format lib/pages/home_page_home_content.dart tests/pages/home_page_short_screen_test.dart` — run; unrelated pre-existing formatter changes were discarded.
- `flutter analyze lib/pages/home_page_home_content.dart tests/pages/home_page_short_screen_test.dart` — no errors; two existing informational lints remain (`no_leading_underscores_for_local_identifiers` in `_statusItem` and `unnecessary_const` in the existing scroll test).
- `git diff --check` — passed.
