# Video gallery duration badge

These screenshots and the motion preview use the production `VideoGalleryPage`
and its real grid thumbnail builder with one safe in-memory video record. The
thumbnail has no cached media, so the production camera-icon fallback is shown;
the same badge builder is shared with the loaded-thumbnail path. No video is
opened, imported, stored, or sent over the network.

## Capture setup

- Viewport: 320 × 640 CSS pixels, device scale factor 1
- Browser: Chromium headless
- Locale: `en_US`
- Screenshots: Material 3 light and dark themes; 1× scale for the fitting
  `360:00` (6 hour) duration, and 3× scale for the clipped `6000:00` (100 hour)
  duration
- Preview: light theme, 3× scale, `6000:00`; 11 seconds at 8 fps. It shows the
  initial one-second still, horizontal reveal to the text endpoint, the
  two-second endpoint pause, and the start of the reverse movement.
- Focus and keyboard: no control focused; browser keyboard closed
- Fixture: `tools/qa/video_gallery_duration_badge_capture.dart`
- Capture script: `tools/qa/capture_video_gallery_duration_badge.py`

Recreate all artifacts from the repository root with:

```sh
python3 tools/qa/capture_video_gallery_duration_badge.py
```

## Screenshots and preview

- Fitting, 1×: [light](video-duration-fitting-6h-320x640-1x-light.png) ·
  [dark](video-duration-fitting-6h-320x640-1x-dark.png)
- Clipped, 3×: [light](video-duration-clipped-100h-320x640-3x-light.png) ·
  [dark](video-duration-clipped-100h-320x640-3x-dark.png)
- [Playable 100-hour horizontal reveal preview](video-duration-100h-reveal-320x640-scale3-light.webm)
