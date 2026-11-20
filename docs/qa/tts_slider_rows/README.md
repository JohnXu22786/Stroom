# TTS slider endpoint labels

The production `TTSCreatePage` is captured at 320 × 640 / 1× in German and the light theme. A temporary local `ProviderEntry` fixture sets very large speed and volume maxima so the endpoint values exercise their clipped, constrained state. The fixture makes no provider request and its temporary entrypoint was removed after capture.

The screenshot shows the speed and volume headings, current values, sliders, and aligned minimum / normal / maximum rows. The playable preview shows the long endpoint labels revealing within their slots.

- [320 × 640 screenshot](slider-labels-de-320x640-1x-light.png)
- [Playable 1× reveal preview](slider-label-reveal-320x640-1x.webm)

Widget checks: `flutter test --no-pub tests/pages/settings/tts_create_page_test.dart --plain-name 'bounded speed and volume sliders'`.
