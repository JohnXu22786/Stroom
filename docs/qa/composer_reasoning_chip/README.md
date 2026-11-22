# Composer reasoning chip bounded label QA

These captures show the production `SettingsChip` used by the chat composer, rendered in a temporary Flutter Web harness at 320 × 640 CSS pixels, DPR 1, and 1× text scale. The selected reasoning option is a long model-provided value (`reasoning_effort_custom_option_value_that_exceeds_phone_width`). The neighboring Tools chip is a fitting label with a badge.

- `reasoning-chip-320x640-light.png` and `reasoning-chip-320x640-dark.png`: captures after the long value has begun moving. The icon and chip outline remain fixed; the Tools label stays stationary and its badge remains visible.
- `reasoning-chip-motion-320x640.webm`: an 8 second playable capture from the light theme. It shows the one-second initial hold, clipped value motion, and stationary fitting label with badge.

The harness used the repository's production `SettingsChip` and `ConstrainedText`; captures were rendered with Flutter 3.47.9 and Chromium. Widget coverage is in `tests/pages/chat/composer/composer_model_name_truncation_test.dart` and `tests/pages/chat/composer/reasoning_chip_display_test.dart`. The existing composer input interaction check also passed: `flutter test --no-pub tests/pages/chat/composer/chat_composer_performance_test.dart --plain-name 'send button enables when user types'`.
