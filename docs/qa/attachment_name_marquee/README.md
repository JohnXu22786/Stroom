# Attachment filename marquee preview

The screenshot and nine-second video show the real `FilePreviewChip` used by the pending-attachment row, with a long document filename in its 48 dp label slot.

[Play the short video](attachment-name-marquee_320x640_1x.mp4)

![FilePreviewChip at the start of the marquee](viewport_320x640.png)

## Viewport and capture

- Logical viewport: 320 × 640 dp
- Device pixel ratio: 1
- Text scale: 1.0
- Theme: light
- Locale: English
- Label slot: 48 dp, with the complete filename supplied to `ConstrainedText`
- Video: 9 seconds, H.264 MP4 at 320 × 640; shows the initial still period and the filename moving until its trailing text is visible

Captured from the running Flutter web app in headless Chromium. The video uses real-time rendered frames at the viewport above; it is not an animation mockup.
