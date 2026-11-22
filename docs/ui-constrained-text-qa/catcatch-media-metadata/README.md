# CatCatch media metadata QA

The screenshot and preview use the production `CatCatchTaskCard` at 320 × 640 CSS pixels, DPR 1, German (`de-DE`), Material 3 light theme, and 1× text scale. A local fixture supplies a long MIME type and a separate-track label. It makes no network or provider request. No control is focused and the keyboard is closed.

- [Production card screenshot](catcatch-media-metadata-de-320x640-1x-light.png)
- [Playable metadata reveal preview](catcatch-media-metadata-motion-320x640.webm)

The screenshot honors reduced motion and shows the full metadata string available in its finite slot. The preview uses normal motion and shows the metadata and split-track text staying within the card while revealing when clipped.

To recreate the capture, build the fixture with `flutter build web --release --no-pub --target tool/qa/catcatch_media_metadata_capture.dart --output /tmp/catcatch-media-metadata-web --no-wasm-dry-run`, serve that directory on port 8879, then run `python3 tool/qa/capture_catcatch_media_metadata.py`.
