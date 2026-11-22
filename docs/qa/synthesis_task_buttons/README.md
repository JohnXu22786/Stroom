# Synthesis action button bounds QA

These screenshots show the production `UnifiedTaskListPage` and `SynthesisTaskCard` at a 320 × 640 CSS-pixel viewport and device scale factor 1. A local fixture supplies paused, failed, and completed synthesis tasks; it uses no real provider or user data.

- Locale: English (`en`)
- Theme: light Material 3 blue seed
- Primary captures: default 1× text scale; supplemental captures: 2.5× text scale
- Focus: none; keyboard: closed
- Motion: disabled; the change adds no motion

The default-scale captures show the unmodified production UI at normal text size. The supplemental 2.5× captures show that the controls grow with scaled labels. All screenshots were captured from the live Flutter Web app in headless Chromium, not reconstructed mockups.

## Default 1× text scale

- [Paused task / Continue](paused-en-320x640-scale1_0.png)
- [Failed task / Retry](failed-en-320x640-scale1_0.png)
- [Completed task / Open File](completed-en-320x640-scale1_0.png)

## Supplemental 2.5× text scale

- [Paused task / Continue](paused-en-320x640-scale2_5.png)
- [Failed task / Retry](failed-en-320x640-scale2_5.png)
- [Completed task / Open File](completed-en-320x640-scale2_5.png)

Reproduce from the repository root:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8877 -t tool/qa/synthesis_task_buttons_capture.dart --no-pub
python3 tool/qa/synthesis_task_buttons_capture.py
```
