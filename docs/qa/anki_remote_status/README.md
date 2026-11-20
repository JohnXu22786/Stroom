# Anki remote status narrow layout QA

The production `AnkiSyncSettingsPage` is rendered in French at a 320 × 640 CSS px viewport and 1× device scale. The available collection heading stays beside its cloud icon inside the card width. Schema details and the server message below it retain natural wrapping.

The capture uses local metadata fixtures only; it makes no provider request. The screenshot honors reduced motion and shows the constrained heading in its initial aligned position. The WebM records the normal horizontal reveal for that same localized heading.

- [Rendered screenshot, 320 × 640, 1×](french-available-320x640-1x.png)
- [Heading reveal, 320 × 640, 1×](french-heading-reveal-320x640-1x.webm)

Widget regression coverage for both available and empty server collections is in `tests/anki/anki_sync_settings_page_test.dart`.
