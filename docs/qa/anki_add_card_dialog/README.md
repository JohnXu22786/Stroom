# Anki add-card dialog QA

The screenshot shows the production `AnkiDroidPage` and its actual add-card dialog at a 320 × 640 CSS viewport, device pixel ratio 1, de-DE locale, light theme, and normal text scale. A temporary fixture entrypoint supplied one local deck plus Basic and Cloze note types, and waited for the local note-type list before rendering the page so the selector was visible when the dialog opened. It made no database or network requests. The screenshot came from a Flutter Web release build rendered in headless Chromium; the fixture was removed after capture.

The localized static form labels use the shared constrained-text behavior. At the narrow viewport, the tags label is longer than its slot and reveals its full text while the text fields and actions remain in place. The Cloze deletion instructions wrap naturally after selecting that note type. The companion widget tests cover 1.8× text, keyboard insets, selecting Cloze, editing all fields, saving, and canceling.

- [Production dialog screenshot, 320 × 640, 1×](anki-add-card-de-320x640-1x.png)
- [Dialog label reveal preview (1× text scale)](anki-add-card-label-reveal.webm)
- Widget regression test: `tests/anki/pages/anki_add_card_dialog_constrained_test.dart`
