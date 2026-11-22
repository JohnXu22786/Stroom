# Anki sync mode label QA

The screenshot and motion preview use the production `AnkiSyncSettingsPage` in
Flutter Web with a safe, logged-out fixture from
`tests/qa/anki_sync_mode_capture.dart`.

- Viewport: 320 × 640 CSS pixels at device scale factor 1.
- Locale: German (`de-DE`).
- Theme: light, using the app's blue-seeded Material 3 fallback theme.
- Text scale: 1×.
- Focus and keyboard: no input focused; software keyboard closed.
- Data and network: a fresh browser profile, no saved Anki session, no account
  data, and no provider or sync request.

The PNG was inspected at full size. The selected check indicator, the
self-hosted mode's DNS icon, and its compact one-line label remain visible.
The WebM shows the clipped label's horizontal reveal while the control retains
its size and selection behavior.
