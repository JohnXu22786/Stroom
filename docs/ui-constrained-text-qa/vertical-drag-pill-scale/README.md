# Drag-sort option pills

These screenshots render the production `DragSortArea` pill widget with safe
in-memory reasoning-option values at 320 × 640 logical pixels, 1× device pixel
ratio, en-US, Material 3 light theme at 1× and 2× text scale, and dark theme at
1× text scale. The pill actions are no-op fixture callbacks; no option is
changed. No control is focused, the software keyboard is closed, and no account
data or network request is used. Chromium uses reduced motion for deterministic
captures, so clipped labels remain at their stationary ellipsis state.

- [Normal 1× text scale](pills-320x640-scale1-light.png)
- [Supplemental 2× text scale](pills-320x640-scale2-light.png)
- [Normal 1× text scale, dark theme](pills-320x640-scale1-dark.png)

The unique functional regression case lives in
`tests/widgets/drag_sort_area_test.dart` (`large text scale grows pill geometry
around text and actions`). The screenshots capture the production widget
through the Chromium renderer. Recreate all images with:

```sh
python3 tool/qa/capture_vertical_drag_pill_scale.py
```
