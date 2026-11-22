# Log settings constrained-label capture

This capture exercises the production `LogViewerPage` and its production settings dialog. A small `MaterialApp` capture entrypoint supplies the app's Material 3 fallback theme, Portuguese (Brazil) localization, and 1× text scale. The dialog was opened through the page's Log settings action; no field was focused and no keyboard was open.

- Viewport: 320 × 640 CSS/logical pixels, Chromium device pixel ratio 1.
- Rendering: Flutter Web release build in Chromium, with platform font rendering (no widget-test font fixture).
- Locale: `pt_BR`.
- Theme: light Material 3, blue seed fallback used by `Application` when dynamic color is unavailable.
- Clipped label: “Limite máximo de armazenamento de registros” in the storage-limit field.
- Fitting stationary label: “Manter registros por” in the retention field.
- Screenshot: [`log-settings-pt-BR-320x640.png`](log-settings-pt-BR-320x640.png), captured before the one-second motion delay elapsed.
- Motion preview: [`log-settings-pt-BR-320x640-motion.mp4`](log-settings-pt-BR-320x640-motion.mp4), 8 seconds at 12 fps. It records the initial log page, opening the settings dialog, the label's initial pause, and its horizontal movement.

The preview keeps the full 320 × 640 page visible. The app-bar title also moves because it is clipped at this viewport; the storage-limit label's movement is visible within the dialog.
