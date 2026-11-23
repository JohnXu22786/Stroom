# Startup update-check snackbar

These captures show the production `StartupDataSafetyBlockPage` during an update check with a local safety-block fixture and a pending fake update notifier. The Flutter Web app hides the update button by design, so the temporary capture entrypoint called the page's production `_checkForUpdate` handler directly through a capture-only bridge. That bridge and entrypoint were removed after capture. No account data, provider request, or network request was used.

- [Normal text at 320 × 640 CSS px, device scale factor 1, de-DE, light Material 3](update-check-de-DE-320x640-1x.png). Text scale is 1×; the full progress label fits and stays still.
- [Expanded text at 320 × 640 CSS px, device scale factor 1, fr-FR, light Material 3](update-check-fr-FR-320x640-text-scale1_8.png). Text scale is 1.8×; the label clips and reveals without horizontal overflow.
- [Real-time clipped-label reveal preview](update-check-fr-FR-motion.webm), captured at 8 fps for 9 seconds.

Neither capture has a focused control or an open software keyboard.
