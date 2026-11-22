# TTS bounded form rows

The TTS synthesis-model selector label and form section headings use finite one-line slots so long localized labels reveal their full text without forcing neighboring controls off screen. The model menu is limited to the available viewport width (up to 360 dp); its options retain the complete model/provider value and remain operable. The original-title chip stays bounded beside its heading; the provider-settings link preserves its tap target while its surrounding sentence wraps.

The screenshot and reveal were captured from the production `TTSCreatePage` using a temporary local provider fixture with long model and provider names; the fixture entrypoint was removed after capture and makes no provider request.

Widget checks cover German at 320 × 640 / 1× in light theme, including opening the model dropdown and selecting a different model, and German at 320 × 640 / 1.6× in dark theme.

- [German 320 × 640 screenshot](tts-form-de-320x640-1x-light.png)
- [Playable model-label reveal](tts-form-de-model-label-reveal.webm)

Test: `flutter test --no-pub tests/pages/settings/tts_create_page_test.dart --plain-name 'narrow localized form rows'`.
