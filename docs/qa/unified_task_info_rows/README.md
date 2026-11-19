# Unified task information and CatCatch URL QA

Each PNG is one side-by-side comparison for one changed UI location. The Chromium capture harness mounts the production `buildInfoRow`, `buildStatusChip`, and `ConstrainedText` widgets in the app's light Material 3 theme. The before panels reproduce the prior fixed-width row and 40-character URL truncation behavior.

## Capture conditions

- Portuguese (Brazil), light theme, text scale 2.0
- Each side is 280 logical pixels wide; the combined image is 560 × 320 pixels at device scale factor 1
- Before source: `origin/main` at `d488629ee19cf1b86cd196e00128c28952225590`
- After source: this batch's task information and CatCatch URL changes

## Comparisons

1. `01-info-row-label.png` — localized result-status label and its value in the shared task information row.
2. `02-status-time-row.png` — status chip and relative time in a narrow task card metadata row.
3. `03-catcatch-card-url.png` — single-line fallback URL title in a collapsed CatCatch task card.
4. `04-resource-selection-url.png` — two-line fallback URL title above CatCatch resource choices.
5. `05-media-preview-title.png` — single-line source title in the media preview sheet.

`url-reveal.webm` is a six-second Chromium preview at the same viewport and text scale. It includes the one-second initial pause and then shows the full CatCatch URL moving through the existing constrained title slot.

## Regression coverage

`tests/pages/unified_task_list/task_info_row_constrained_text_test.dart` checks a long localized info label at 280 dp and text scale 2.0. The existing background-card, shared task-list, and media-preview tests cover the other updated call sites and their surrounding controls.
