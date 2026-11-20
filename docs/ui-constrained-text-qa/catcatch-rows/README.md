# CatCatch constrained rows QA

The production `CatCatchPage` was rendered in Chromium at 320 × 640 CSS px, device scale factor 1, and de-DE. The fixed bottom bar now keeps both folder selector labels and the chevron in place while a long folder path is revealed within its remaining width. The task count and duration preview use finite slots in their compact rows. Root-folder text stays stationary when it fits.

## Captures

- [Fitting root folder](catcatch-root-de-320x640-scale1-light.png)
- [Long selected folder](catcatch-long-folder-de-320x640-scale1-light.png)
- [Long folder reveal motion](catcatch-long-folder-motion.webm)

The motion preview uses the shared `ConstrainedText` delayed, bidirectional reveal. The exact folder string remains the widget's complete label and semantic value.

## Verification

`tests/pages/catcatch_page_constrained_rows_test.dart` exercises the production page at 320 × 640, de-DE, and 1× text scale. It selects a long folder, confirms the fitting root state, then checks that the duration preview, task count, full folder value, and page layout remain available without a framework overflow. A second test checks the task count at 1.6× text scale in dark theme.
