# Unified task information and CatCatch URL QA

Each PNG is a full rendered phone screen, with the page before the change on the left and the page after the change on the right. These captures use the app's real `TaskListPage` or `UnifiedTaskListPage`; they are not isolated widget crops or a mock page shell. The media-preview comparison shows the production bottom sheet over the actual unified task list.

## Capture conditions

- Chromium rendering of the Flutter Web app and production pages/widgets
- 320 × 900 logical-pixel viewport per side, device scale factor 1
- Portuguese (Brazil), light Material 3 theme, text scale 2.0
- Before source: `992481ff90017b5f4d041189bb14377348adff62`
- After source: `0df0c31d1bdae4feceee1aabb92fb07e61d256c8`
- Both sides use the same task scenario, viewport, locale, and theme

## Comparisons

1. `01-info-row-label.png` — actual unified task list with an expanded OCR background task and its status detail row.
2. `02-status-time-row.png` — actual synthesis task list with the production task title, status, and relative-time row.
3. `03-catcatch-card-url.png` — actual unified task list with a collapsed CatCatch task and its URL title.
4. `04-resource-selection-url.png` — actual unified task list with a CatCatch resource-selection task.
5. `05-media-preview-title.png` — actual unified task list with the production media preview sheet open over it.

The URL scenarios reproduce the old 40-character fallback passed by the former caller and the full URL passed by the updated caller. Screens were captured after Flutter Web completed the initial page layout; constrained titles were allowed to scroll before capture.

`url-reveal.webm` is an 8-second capture of the actual unified task list at the same 320 px phone width, showing the full URL moving through the CatCatch title slot.

## Regression coverage

`tests/pages/unified_task_list/task_info_row_constrained_text_test.dart` checks a long localized info label at 280 dp and text scale 2.0. Existing background-card, shared task-list, and media-preview tests cover the other updated call sites and their surrounding controls.
