# File manager back-row path QA

The production `FileManagerView` back row was captured in Chromium at 320 × 640 CSS pixels, device scale factor 1, and 1× text scale. The fitting `notes` path stays stationary and right-aligned. The long `archive/2026/research/weekly-reports/quarterly-review` path is clipped to its row slot and reveals across the full value after the shared delayed-motion start; the back icon remains visible.

## Captures

- [Fitting path](back-row-fitting-320x640-scale1.png)
- [Clipped path](back-row-clipped-320x640-scale1.png)
- [Playable clipped-path reveal](back-row-clipped-motion-320x640-scale1.webm)

The captures use the real shared file-manager widget and its localized back-row label. A temporary Flutter Web entrypoint supplied empty records and the two folder paths; it was removed after capture.
