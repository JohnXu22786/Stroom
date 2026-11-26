# Failed task detail label

These screenshots capture the production `TaskListPage` and its `TaskCard` in Chromium with an in-memory failed-task fixture that uses the long timeout error. No provider request or user data is used. Device scale factor is 1. The narrow capture is cropped from y=160 to the bottom of its 240 × 640 viewport so the failed-task state and detail row remain visible. It uses normal motion; the screenshot shows a partial segment of the label reveal alongside the error icon, while the complete value remains available to semantics. The fitting capture uses reduced motion.

- [Narrow German card](task-detail-de-240x640-scale2_5.png): 240 × 640 logical pixels, de-DE, light Material 3 theme, 2.5× text scale, task-flow ownership restoring, normal motion. The crop shows the error icon and a partial label segment inside the measured slot; the full detail value remains available to semantics.
- [Fitting English card](task-detail-en-700x640-scale1.png): 700 × 640 logical pixels, en, light Material 3 theme, 1× text scale, standalone failed task, reduced motion. The label remains ordinary stationary text and the task controls remain in their normal layout.

Capture with:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8878 -t tool/qa/task_list_error_detail_capture.dart --no-pub
python3 tool/qa/task_list_error_detail_capture.py
```

The narrow German capture uses 240 × 640 CSS pixels, de-DE, 2.5× text scale, a light Material 3 theme, and task-flow ownership restoring; its PNG is cropped to y=160–640. The fitting English capture uses 700 × 640 CSS pixels, en, 1× text scale, the same theme, and standalone ownership ready; it shows the stationary detail label and normal task controls.

The widget regression is in `tests/pages/task_list_shared_test.dart` and covers both the clipped narrow state and the fitting stationary state.
