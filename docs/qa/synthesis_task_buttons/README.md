# Synthesis action button bounds QA

These screenshots show the production `UnifiedTaskListPage` and `SynthesisTaskCard` at a 320 × 640 CSS-pixel viewport and device scale factor 1. A local fixture supplies paused, failed, and completed synthesis tasks; it uses no real provider or user data.

- Locale: Simplified Chinese (`zh-CN`)
- Theme: light Material 3 blue seed
- Text scale: 2.5×
- Focus: none; keyboard: closed
- Motion: disabled; the change adds no motion

The three captures show the full Continue, Retry, and Open File controls with room for their large text. They were captured from the live Flutter Web app in headless Chromium, not reconstructed mockups.

- [Paused task / Continue](paused-zh-CN-320x640-scale2_5.png)
- [Failed task / Retry](failed-zh-CN-320x640-scale2_5.png)
- [Completed task / Open File](completed-zh-CN-320x640-scale2_5.png)

Reproduce from the repository root:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8877 -t tool/qa/synthesis_task_buttons_capture.dart --no-pub
python3 tool/qa/synthesis_task_buttons_capture.py
```
