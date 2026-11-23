# Drag-sort option pills

These screenshots render the production `DragSortArea` pill widget with safe
in-memory reasoning-option values at 320 × 640 logical pixels, 1× device pixel
ratio, en-US, Material 3 light theme, and 1× or 2× text scale. The pill actions
are no-op fixture callbacks; no option is changed. No control is focused, the
software keyboard is closed, and no account data or network request is used.

- [Normal 1× text scale](pills-320x640-scale1-light.png)
- [Supplemental 2× text scale](pills-320x640-scale2-light.png)
- Functional regression owner: `tests/widgets/drag_sort_area_test.dart`

The functional regression owner is `tests/widgets/drag_sort_area_test.dart`;
the screenshots capture the production widget through the Chromium renderer.
Recreate both images with:

```sh
python3 tool/qa/capture_vertical_drag_pill_scale.py
```
