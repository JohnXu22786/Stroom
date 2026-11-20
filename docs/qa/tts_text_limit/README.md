# TTS text-limit warning

These captures use the production `TTSCreatePage` at 320 × 640 CSS pixels and device scale 1. A temporary Flutter Web entrypoint supplied a local TTS model with a one-character limit and a French over-limit value; it made no provider request and was removed after capture. The warning keeps its red style and icon beside the count badge. The row gives its localized label a finite single-line slot, so a clipped value reveals horizontally without moving the badge or changing text-field editing.

The targeted widget checks cover the German warning in light theme at 1× text scale while editing from under-limit to over-limit and clearing, plus dark theme at 1.6× text scale.

- [Rendered 320 × 640 screenshot, 1×, light theme](limit-warning-fr-320x640-1x-light.png)
- [Playable localized warning reveal](limit-warning-reveal.webm)

Widget test: `flutter test tests/pages/settings/tts_create_page_test.dart --plain-name 'text limit warning'`.
