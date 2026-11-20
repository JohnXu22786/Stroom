# Unified task information and CatCatch URL QA

Each PNG is a side-by-side comparison of the real app page: the complete 320 × 720 phone viewport from before is on the left and after is on the right. A 28 px header identifies the source commits. The images are 640 × 748 px. Captures use the production `TaskListPage` or `UnifiedTaskListPage`, real task cards, and the production Application theme (blue seed, Material 3, app bar and card themes). The media-preview comparison opens the production bottom sheet from the CatCatch resource row.

## Capture conditions

- Chromium rendering of Flutter Web at a 320 × 720 logical-pixel viewport per side, device scale factor 1
- Portuguese (Brazil) locale (`pt-BR`), light theme; locale is a screenshot-fidelity choice only and does not claim coverage for Chinese or other locales
- Flutter's ordinary/default text scale (1.0); no `MediaQuery.textScaler` override
- Before source: full checkout at `992481ff90017b5f4d041189bb14377348adff62`
- After source: full checkout at `7bbc98644124b5c9e4eef842eed5b5d80851fd04`
- Matching task seed, viewport, locale, theme, and default text scale on both sides
- Static captures use `MediaQueryData.disableAnimations = true` in the temporary capture harness. The CatCatch URL comparison (#03) is captured separately with normal motion 9 seconds after page load, near the readable URL-tail endpoint so the newly exposed URL text can be compared with the older truncated prefix. No text scale is changed.

## Comparisons

1. `01-info-row-label.png` — `UnifiedTaskListPage` with an expanded OCR background task and its partial-result status row.
2. `02-status-time-row.png` — `TaskListPage` with the completed synthesis task status and relative-time row; the completed state keeps the icon stable on both sides.
3. `03-catcatch-card-url.png` — `UnifiedTaskListPage` with a CatCatch task whose title falls back to `https://e.co/watch/catcatch-long-title-example-video`. The before side shows the original shortened prefix; the after side is captured near the readable URL-tail endpoint (9 seconds after page load).
4. `04-resource-selection-url.png` — the same page with CatCatch waiting for resource selection and the URL shown in the selection view.
5. `05-media-preview-title.png` — the production media-preview bottom sheet opened from the playable resource row on the actual unified task list.

`url-reveal.webm` is an 8-second, 320 × 108 clip of the real `UnifiedTaskListPage` at default text scale and normal motion. It is framed to the CatCatch task-card title region (page route `/?s=3`, y=112–220 of the 320 × 720 logical viewport) so sampled frames show the moving URL without the independently scrolling app-bar tab labels. The clip uses rendered production pixels; no UI is overlaid or altered. The full source URL is visible in successive readable segments as it moves through the title slot.

The headless Chromium media-preview capture displays the production sheet title and the expected `path_provider` web-platform error in the preview area; the selected task title comparison remains visible above it.
