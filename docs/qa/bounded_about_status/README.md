# About dialog and update-check status labels

The captures show production `SettingsPage` UI at 320 × 640 CSS pixels, device scale 1, default 1× text scale, in French and Material 3 light theme. The privacy dialog title stays beside its icon while the privacy policy body wraps and scrolls. The update-check SnackBar keeps its progress indicator visible beside its complete localized status label.

- [Privacy dialog screenshot](privacy-dialog-fr-320x640-1x.png) — real dialog and localized policy text during the title reveal.
- [Update-check status screenshot](update-check-status-fr-320x640-1x.png) — real About update-check row with the pending-check SnackBar.
- [Playable 1× motion preview](privacy-title-motion-1x.webm) — 5.5 seconds of the real dialog title reveal.

The capture harness used a pending in-memory update notifier and made no update request. For browser capture only, the existing non-web guard around the update entry was temporarily bypassed so the production SnackBar could be opened; that source guard was restored after capture. The temporary harness was removed.

The targeted widget tests cover narrow French/German overflow and fitting English labels, the full localized values, the dialog close action, and the pending update check beside its spinner.
