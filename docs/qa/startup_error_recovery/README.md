# Startup recovery error details

The screenshot shows the production `StartupErrorBoundary` recovery screen at 320 × 640 CSS pixels, device scale factor 1, English (`en-US`), normal 1× text scale, and the blue-seeded Material 3 light theme. The viewport is scrolled to the end of a long diagnostic so the Retry button is visible and operable. The repeated diagnostic is a local fixture; no provider or network request is made.

- [Production screen after scrolling to Retry](startup-error-recovery-en-320x640-1x-light.png)

The capture used a temporary Flutter Web entrypoint with the production boundary and was rendered in headless Chromium. The temporary entrypoint was removed after capture. The widget regression test is `tests/startup/startup_error_recovery_scroll_test.dart`.
