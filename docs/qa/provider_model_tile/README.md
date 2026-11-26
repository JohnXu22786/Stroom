# Provider model tile labels

The production `ProviderConfigDetailPage` model tile had no line limits on its
name or localized model-ID text. At a 320 × 640 logical viewport with German
text at 1.8× scale, the name wrapped to a 473 px text block inside a 160 px
slot, making the compact model row expand far beyond its intended height.
Both values now use the shared measured one-line `ConstrainedText` behavior.
They stay in their original leading alignment when they fit and reveal only
when their actual slot clips them.

## Captures

- `narrow-de-320x640-scale1_8-light.png`: production page at 320 × 640 CSS px,
  DPR 1, German (`de-DE`), 1.8× text scale, LTR, light theme. The synthetic
  model name and ID exceed the finite tile slots; drag, delete, and open controls
  remain visible.
- `fitting-en-1000x800-scale1-light.png`: fitting English (`en`) baseline at
  1000 × 800 CSS px, DPR 1, 1× scale, LTR, light theme. Both labels remain
  stationary at their original leading alignment.
- `narrow-de-reveal-320x640-scale1_8-light.webm`: playable reveal from the same
  production page and viewport as the narrow capture.

The fixture is local synthetic provider/model data and makes no network
requests. Run `python3 tool/qa/capture_provider_model_tile.py` to rebuild the
capture harness and artifacts. The harness is
`tool/qa/provider_model_tile_capture.dart`.
