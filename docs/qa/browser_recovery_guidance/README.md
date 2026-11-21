# Browser recovery guidance

The screenshot is the production `BrowserPage` in recovery mode at 320 × 640 CSS pixels, device scale factor 1, English (`en-US`), the blue-seeded Material 3 light theme, and normal 1× text scale. The guidance wraps across three lines and is fully visible. The URL field is unfocused; headless Chromium does not show a software keyboard. The recovery Continue action is disabled because the local fixture contains no media, while the user-script action remains available.

The page loads a self-contained `data:` HTML fixture from [`tool/qa/browser_recovery_guidance_capture.dart`](../../../tool/qa/browser_recovery_guidance_capture.dart); it makes no external requests. The capture harness opens the production recovery page directly and does not alter the recovery flow. No animated text is used, so a playable preview is not applicable.

- [Production recovery page at 320 × 640, 1×, light](browser-recovery-en-320x640-1x-light.png)

To reproduce the screenshot, build with `flutter build web --release --no-pub --target tool/qa/browser_recovery_guidance_capture.dart --output /tmp/stroom-browser-recovery-web --no-wasm-dry-run`, serve that directory locally, then capture at 320 × 640 with device scale factor 1.
