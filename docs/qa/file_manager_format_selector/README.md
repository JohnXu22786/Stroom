# File manager format selector label

`format-selector-en-320x640-1x-light.png` shows the production `FileManagerView` rename dialog in Chromium at a 320 × 640 CSS-pixel viewport, device scale factor 1, English (United States), light theme, and normal 1× text scale. The `txt` option is selected. The filename field contains `notes`, is unfocused, and no keyboard is shown. The fixture is local and makes no file writes or network requests.

The production `fileManagerFormat` value (`Format`) fits in this layout, so it stays stationary as required. `format-label-motion-preview-test-only-long-localization.webm` is separate test evidence: the same production selector is rendered at the same viewport and scale, but a capture-only localization replaces the label with `Format label for test-only clipping evidence` to demonstrate the clipped-label motion. That string is not a shipped translation. The preview uses normal text scale and real Chromium/Flutter fonts; it is not a test-font render.

- [Production selector screenshot, 320 × 640, 1×](format-selector-en-320x640-1x-light.png)
- [QA-only clipped-label motion preview](format-label-motion-preview-test-only-long-localization.webm)
- [Capture entrypoint](../../../tool/qa/file_manager_format_capture.dart); run the release web app with `?longLabel=true` for the clearly disclosed motion fixture.
