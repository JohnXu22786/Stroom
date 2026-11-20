# Unified task card label QA

The production `BackgroundTaskCard` error heading and its “view details” action now use flexible `ConstrainedText` slots. Their icons and card actions stay in place, and the diagnostic body remains ordinary wrapping text.

- [Arabic error row at 320 × 640, DPR 1, 1× scale, light theme](background-error-ar-320x640-1x.png)
- [Three-second playable static Arabic preview at 320 × 640, DPR 1, 1× scale](background-error-ar-static-preview-320x640-1x.webm)
- [Playable Arabic label reveal at 320 × 640, DPR 1, 1.8× scale](background-error-label-motion-320x640-1_8x.webm)

The screenshot and 1× preview show the production card in Flutter Web Release mode with local task data. The Arabic error heading and “view error details” action fit at normal scale, so the 1× preview holds the real component capture still for three seconds. The 1.8× motion preview shows the complete action label moving only within its allotted row slot. Chromium reported no page errors during the component captures.

`tests/pages/unified_task_list/bounded_task_labels_test.dart` covers the localized error row at the narrow viewport and verifies that the synthesis error-dialog title and close action remain bounded while the diagnostic body stays selectable. The grouped-duration helper in `CatCatchTaskCard` currently has no callers, so it was left unchanged.
