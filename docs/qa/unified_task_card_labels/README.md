# Unified task card label QA

The production `BackgroundTaskCard` error heading and its “view details” action now use flexible `ConstrainedText` slots. Their icons and card actions stay in place, and the diagnostic body remains ordinary wrapping text.

- [Arabic error row at 320 × 640, DPR 1, 1× scale, light theme](background-error-ar-320x640-1x.png)
- [Playable Arabic label reveal at 320 × 640, DPR 1, 1.8× scale](background-error-label-motion-320x640-1_8x.webm)

Both captures use the production card in Flutter Web Release mode with local task data. The motion preview shows the complete “view error details” label moving only within its allotted row slot. Chromium reported no page errors.

`tests/pages/unified_task_list/bounded_task_labels_test.dart` covers the localized error row at the narrow viewport and verifies that the synthesis error-dialog title and close action remain bounded while the diagnostic body stays selectable. The grouped-duration helper in `CatCatchTaskCard` currently has no callers, so it was left unchanged.
