# Anki empty study narrow layout QA

The production `AnkiStudyPage` empty state is rendered in Spanish at a 320 × 640 logical-pixel viewport and 1× device scale. The message and original-size celebration icon remain centered when they fit; the page scrolls vertically when enlarged text needs more height so the back action stays reachable.

The capture is the real production page widget in a localized `MaterialApp` with local deck and empty-card fixtures. It makes no database or provider requests. The widget regression suite also exercises the 1.8× text layout, the back action, and the populated study answer flow.

- [Rendered screenshot, 320 × 640, 1×](anki_empty_study_320x640_1x.png)
- Widget regression coverage: `tests/anki/pages/anki_study_empty_scroll_test.dart`
