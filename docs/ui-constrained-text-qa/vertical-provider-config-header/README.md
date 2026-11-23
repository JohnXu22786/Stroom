# Provider configuration header

`provider-config-header-fr-320x640-scale1-light.png` is a production Flutter Web capture of `ProviderConfigPage` at a 320 × 640 CSS-pixel viewport and device scale 1. It uses fr-FR, the light Material 3 theme, default 1× text scale, no focused control, and a closed keyboard. The fixture is an unsaved in-memory LLM provider; it makes no provider request and uses no account data.

The configuration heading wraps within the width left by the add action. The add action stays aligned to the trailing edge, and wider layouts retain the original single-row presentation.

`tests/pages/settings/provider_config_header_responsive_test.dart` owns the widget regression test. It checks the French heading at 320 × 640, a keyboard-inset state, a German heading at 1.6× text scale, and the 600-pixel wide layout. Functional suite mapping: `provider-settings`; CI test owner: `feature-ui`.

The capture is produced by `tools/qa/capture_vertical_provider_config_header.py` using `tool/qa/vertical_provider_config_header_capture.dart`.
