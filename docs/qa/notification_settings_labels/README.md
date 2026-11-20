# Notification settings label captures

These captures show the real `NotificationSettingsPage` running in Flutter Web. The web permission state displays the unsupported notice and keeps the request action visible; the narrow captures exercise the request action beside its icon. The widget test also checks the `Open System Settings` action shown for permanently denied permission.

- `narrow-fr-light.png` and `narrow-fr-dark.png`: 340 × 1800 viewport, French, 1.5× text scale. The action labels overflow their button slots and move while the icons and button geometry stay fixed.
- `wide-en-light.png` and `wide-en-dark.png`: 840 × 1400 viewport, English, 1× text scale. The labels fit and remain stationary.

Captured with Chromium from a Flutter web development server after the page rendered. The screenshots cover light and dark themes. They are visual review artifacts, separate from the targeted widget regression test in `tests/pages/settings/settings_page_test.dart`.
