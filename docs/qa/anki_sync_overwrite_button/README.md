# Anki overwrite action at a narrow viewport

- Production page screenshot: [overwrite-server-de-DE-320x640-1x-light.png](overwrite-server-de-DE-320x640-1x-light.png)
- Playable motion preview: [overwrite-server-reveal-de-DE-320x640-1x-light.webm](overwrite-server-reveal-de-DE-320x640-1x-light.webm)
- Viewport: 320 × 640 logical pixels, device scale factor 1
- Locale: German (`de-DE`)
- Theme: light Material 3; text scale 1.0
- Focus: no text field focused; keyboard closed
- Fixture: local fake AnkiWeb credentials and metadata for the page screenshot; no live account or server

The PNG is a capture of the production `AnkiSyncSettingsPage` after scrolling to the overwrite action. The 10-second WebM is a real-time Chromium capture of the production `ConstrainedText` and `FilledButton.tonalIcon` with the same German label, icon, theme, viewport, and button width. Its measured overflow makes the shared label reveal motion visible. The preview harness and capture command are `tool/qa/anki_sync_overwrite_button_animation_capture.dart` and `tool/qa/capture_anki_sync_overwrite_button_animation.py`.
