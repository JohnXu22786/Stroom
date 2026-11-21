# Anki login label visual QA

Captured the production `AnkiSyncSettingsPage` in Chromium at 320 × 640 CSS pixels, device scale factor 1, German locale, light Material 3 theme, and normal text scale. The username field is focused with the local fixture `sample@example.invalid`; its long localized label visibly reveals as it clips. The shorter `Passwort` label fits and remains stationary. The screenshot shows the actual production page and browser fonts.

- [Focused screenshot](anki-sync-login-de-320x640-1x-light-focused.png)
- [Playable label reveal](anki-sync-login-de-320x640-1x-light-label-reveal.webm)
- [Capture harness](../../../tool/qa/anki_sync_labels_capture.dart)

The harness opens the page directly because the full application startup presents a migration restart dialog. Secure storage returns no saved credentials. No password was entered, the form was not submitted, and no sync was started. The browser capture allowed only localhost and static Flutter/font assets; application API requests were blocked. Chromium's software keyboard was closed.
