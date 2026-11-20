# Background optimization detail QA

The screenshot shows the strategy-toggle `SwitchListTile` layout with the production German watchdog title and detail, plus a short fitting example. The subtitle retains paragraph breaks and wraps naturally; the info affordance and switch remain in their original positions.

| Condition | Value |
|---|---|
| Viewport | 320 × 640 CSS px, device scale factor 1 |
| Locale | German (`de-DE`) |
| Text scale | 1× |
| Theme | Material 3 light |
| Renderer | Flutter Web release build in Chromium |

- [German 320 × 640 capture](german_320x640_1x.png)

The targeted production-page widget test checks that the German watchdog and cold-start subtitles equal their full localized strings. No animation changed, so no motion preview was needed.
