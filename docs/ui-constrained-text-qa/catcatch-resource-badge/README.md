# CatCatch resource kind badges QA

The production `CatCatchTaskCard` is rendered at 320 × 640 CSS pixels and DPR 1 using a local in-memory fixture with segment, playlist, and full-video resources. The still screenshot uses French (`fr-FR`), Material 3 light theme, and 1× text scale; the playlist row is selected and the segment group is expanded. No control is focused, the keyboard is closed, and the fixture makes no network or provider request.

- [Production card screenshot](resource-kind-badges-fr-320x640-scale1-light.png)
- [Clipped badge reveal preview](resource-kind-badge-motion-pt-200x640-scale1.webm)

The screenshot shows the responsive narrow layout and original badge colors. It uses Material 3 light theme with no focused control and a closed keyboard. The preview scrolls the resource rows into view in Portuguese (`pt-BR`) at 200 × 640 CSS pixels and 1× text scale; its narrow row clips the playlist badge and shows its reveal using the shared `ConstrainedText` timing. It also uses the light theme with no focused control and a closed keyboard.

To recreate the artifacts, build the fixture with:

```sh
flutter build web --release --no-pub --target tool/qa/catcatch_resource_badge_capture.dart --output /workspace/.cloud-profile-state/vertical_catcatch_resource_badge/web-build --no-wasm-dry-run
python3 tool/qa/capture_catcatch_resource_badge.py
```
