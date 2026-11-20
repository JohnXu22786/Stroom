# Update dialog status labels

The completed-download and installing status rows use flexible one-line `ConstrainedText` slots. Labels that fit keep their existing size and alignment; clipped translations reveal the complete value without changing the status icon, update actions, or update operations.

The widget tests measure the German labels at a 320 × 640 viewport and 1.8× text scale in light and dark themes, confirming each label exceeds its finite slot and causes no layout exception. The screenshot shows the real completed-download dialog at 320 × 640, device scale 1, German locale, light theme and 1.8× text scale. It captures the trailing reveal endpoint, where the final localized characters are visible. No update request is made; the capture uses a local `UpdateState` fixture.

- [Rendered status at the trailing reveal endpoint, 320 × 640, 1×](german-complete-320x640-1x.png)
