# File manager toolbar title

The capture uses the production `FileManagerView` at 320 × 640 CSS pixels, device pixel ratio 1, English (United States), light Material 3 theme, and normal 1× text scale. It shows the root folder with the list view active and one local example text file. The configured title (`A long sample file manager title for clipped reveal`) is synthetic capture text, used to exercise the clipped-title path; it is not a shipped localization. No file or network action is performed.

- [Production screenshot, clipped title](title-clipped-320x640-1x-en-US-light.png)
- [Playable clipped-title reveal](title-reveal-320x640-1x-en-US-light.webm)
- [Capture entrypoint](../../../tool/qa/file_manager_title_capture.dart)

To reproduce, build the release capture with `flutter build web --release --no-pub --target tool/qa/file_manager_title_capture.dart --output /tmp/stroom-file-manager-title-web --no-wasm-dry-run`, serve the output, and open it in Chromium at 320 × 640 with device pixel ratio 1. The screenshot was taken after the reveal's initial stationary interval; the preview shows the full toolbar title moving within the available title slot.
