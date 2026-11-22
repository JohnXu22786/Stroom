# Search filter overflow captures

These captures use the production `SearchPanel` widget in a small Flutter Web QA harness. Chromium ran at a 320 × 640 CSS viewport and device scale factor 1.

- `search-panel-filters-es-320x640-scale1-light.png` shows the complete Spanish filter labels at 1×. Both chips keep their natural size and stay stationary after the marquee delay.
- `search-panel-filters-de-320x640-scale1-results.png` shows the localized results count aligned at the right of the filter row.
- `search-panel-filters-de-320x640-scale1_25-light.png` and `search-panel-filters-de-320x640-scale1_25-dark.png` show long German labels clipped within their chips at 1.25× text scaling.
- `search-panel-filters-de-320x640-scale1_25-light-motion.webm` is the playable preview of the clipped labels scrolling to reveal their full text.

The capture harness is temporary and is not part of the application. It mounted the production `SearchPanel` and used the app's generated localizations and Material theme.
