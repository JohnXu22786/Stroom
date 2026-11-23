# Task Flow block card header

The screenshot shows the production `BlockChainEditor` at 320 × 640 CSS pixels, device scale factor 1, Brazilian Portuguese (`pt-BR`), Material 3 light theme, and normal 1× text scale. A safe in-memory flow includes an audio-separation step followed by speech recognition so the temporary-output checkbox is available. No control is focused, the software keyboard is closed, and no task or provider request is started.

The block title has a full-width line above its wrap-capable action row. The title remains readable, and the temporary-output, settings, replace, and menu controls remain visible. This is a static layout change, so there is no motion preview.

## Artifact

- [Production component screenshot](flow-block-card-pt-BR-320x640-scale1-light.png)

## Capture

Build the fixture with `flutter build web --release --no-pub --target tool/qa/vertical_flow_card_header_capture.dart --output <temporary-web-output> --no-wasm-dry-run`, serve that output on port 8892, then run `python3 tool/qa/capture_vertical_flow_card_header.py`. The fixture seeds only local, in-memory block data.
