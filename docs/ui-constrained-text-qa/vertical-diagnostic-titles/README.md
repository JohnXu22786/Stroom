# Vertical diagnostic dialog titles

These captures use the production `showDataDetailDialog` with local request and response fixtures only. No provider call is made.

- [Primary German render, 320 × 640 logical pixels, 1× text, light theme](data-details-de-320x640-1x-light.png). The section-list title `Datendetails` is visible and stationary; all existing icons and actions remain in place.
- [Spanish selected-section state at 1.8× text](data-request-headers-es-320x640-1_8x-light.png).
- [Playable selected-title reveal](data-request-headers-es-320x640-1_8x-light-motion.webm) — 10.52 seconds, 320 × 640, VP8 WebM. The long selected section title moves inside its finite slot while the leading back/info icons and close action stay visible.

The primary image shows the real data-detail section-list state with local request and response samples, German (`de`), 1× text, and the app's blue-seeded Material 3 light theme. A temporary Flutter Web entrypoint opened the production `showDataDetailDialog`; capture waited until the dialog was visibly rendered, then the entrypoint was removed. The release build ran in headless Chromium at a 320 × 640 CSS viewport and device scale factor 1 (Flutter 3.47.9, Dart 3.13.7, Chromium 154.0.8037.57). The motion preview selects the localized Spanish request-header section at 1.8× text to exercise clipped text; initial blank browser startup frames were trimmed after confirming that the selected title moves between the visible start and later frames. Chromium reported no page or console errors.

Focused widget tests cover both diagnostic dialog headings at a 320 × 640 logical viewport and 1.8× text scale, including back and close actions. Shared `ConstrainedText` tests also verify that fitting text stays still and clipped text begins its delayed horizontal reveal.
