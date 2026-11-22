# Background optimization detail QA

The screenshot shows the production background optimization page in German at the battery reminder setting. Its switch and title occupy their own row, and the complete multi-paragraph detail wraps beneath it at the card's full content width. The end of the cold-start explanation is also visible above.

| Condition | Value |
|---|---|
| Viewport | 320 × 640 CSS px, device scale factor 1 |
| Locale | German (`de-DE`) |
| Text scale | 1× |
| Theme | Material 3 light |
| Renderer | Flutter Web debug build in Chromium; Android strategy controls enabled by the temporary local visual harness |

- [German 320 × 640 capture](german_320x640_1x.png)

The focused production-page widget test checks that German watchdog and cold-start details receive more than 240 logical pixels at a 320 logical-pixel viewport width. No animation changed, so no motion preview was needed.
