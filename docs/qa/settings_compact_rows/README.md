# Compact settings row QA

These captures use the production `SettingsPage` at device-pixel ratio 1. The viewport and state are named in each file. The examples use de-DE and the default context-management state: tool pruning is on and the compaction summary is `Globaler Auslöser 95%`.

- `de-320x640-1x-light.png` and `de-320x640-1x-dark.png` show the narrow phone layout at the normal 1× text scale. The long tool-pruning title stays in its row beside the switch; the summary wraps to two visible lines and reveals clipped content vertically.
- `de-840x900-1x-light.png` shows the wider layout at 1×. The full localized title and summary fit and stay still; the switch and navigation affordances remain aligned.
- `de-320x640-1_5x-light.png` is a separate 1.5× text-scale check. It is intentionally identified as enlarged text, not the normal-scale example.
- `de-320x640-1x-motion.webm` is a 12-second playable capture of the production page. It shows the initial one-second stationary period, the heading moving horizontally, and the two-line summary revealing vertically through its clipped content and endpoints.

The page was rendered from a temporary QA entrypoint mounting `SettingsPage` with the production localization delegates and theme. Chromium reported no page or console errors. The temporary entrypoint was removed after capture.
