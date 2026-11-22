# Version information dialog labels

The production `VersionInfoDialog` used to overflow its title row and information rows at 320 × 640 when German text was enlarged. The title and labels now have finite measured `ConstrainedText` slots; fitting values remain stationary and clipped values move to reveal their full text. Version and release-time values still wrap in the remaining row width. Release notes remain ordinary wrapping content in the scrollable dialog.

Captured from the production widget in a Flutter Web release build with Chromium at a 320 × 640 CSS viewport and device pixel ratio 1:

- [German, 1× text, light theme](german-320x640-text1-light.png) — the title and release-time label exceed their available slots and reveal their full text over time.
- [German, 1.8× text, light theme](german-320x640-text1_8-light.png)
- [German, 1.8× text, dark theme](german-320x640-text1_8-dark.png)
- [Playable 12-second label reveal at 1.8×, light theme](german-label-reveal-320x640-text1_8-light.webm) — the title and release-time label move within their slots. The long release-note body remains static and wraps naturally.

The focused widget tests cover the German title and labels at large text scale, in light and dark themes. Browser capture completed without console or page errors.
