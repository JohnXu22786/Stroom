# Synthesis task input at a narrow phone width

These Chromium captures use the production `SynthesisTaskCard` at 320 × 640 CSS pixels, device scale factor 1, English (US), 1× text, and the Material 3 light theme. The failed task is expanded, with a long synthesis input and its existing retry, menu, status, and error controls.

- `task-card-320x640.png` shows the bounded four-line excerpt and its open-full-text icon. The existing task controls remain visible; the icon's accessible tooltip is **View full synthesized text**.
- `full-text-dialog-320x640.png` shows the full-text dialog at its initial scroll position.
- `full-text-dialog-bottom-320x640.png` shows the dialog after scrolling through the long body.

The component was rendered in Chromium from a temporary Flutter Web entrypoint and the production theme and generated localizations. The browser reported no console or page errors. The test `tests/pages/unified_task_list/synthesis_task_card_error_layout_test.dart` verifies that the complete input opens in a scrollable dialog.
