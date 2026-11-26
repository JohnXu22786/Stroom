# Anki card browser search hint

These artifacts render the production `AnkiCardBrowser` in Flutter Web/Chromium with an empty local card DAO. The French view is 320 × 640 CSS pixels, device pixel ratio 1, `fr_FR`, light theme, 1.8× text scale, and an empty focused search field. The still shows the hint partway through its reveal so the clipping boundary is visible; the 9-second, 10-fps WebM uses the component's normal timing and shows the full measured horizontal reveal. The English comparison is 390 × 844 CSS pixels, device pixel ratio 1, `en_US`, light theme, 1× text scale, with the same empty focused field; its hint fits and remains stationary.

- `anki-search-hint-fr-320x640-scale1_8-light.png` — narrow expanded-scale production state.
- `anki-search-hint-reveal-fr-320x640-scale1_8-light.webm` — real-time reveal preview.
- `anki-search-hint-en-390x844-scale1-light.png` — fitting comparison state.

Rebuild and recapture with:

```sh
python3 tool/qa/anki_card_browser_search_hint_capture.py
```

The script builds `tool/qa/anki_card_browser_search_hint_capture.dart`, serves it locally, captures both production states and records the animation preview. It makes no database, account, or network requests.
