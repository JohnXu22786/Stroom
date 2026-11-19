# Model Config constrained text QA

Each PNG is one side-by-side comparison for one changed location. The captures use a temporary Material 3 harness that mounts the production `ModelConfigPage` in Chromium. The harness uses the app's blue-seeded fallback color scheme and zero-elevation cards.

## Capture conditions

- Spanish (`es`), light theme, 280 × 800 logical pixels, device pixel ratio 1
- Text scale 2.0
- Before: `origin/main` at `e8d186672ef715322a6e6651c79b200512acfc76`
- After: candidate source after responsive layout and `ConstrainedText` changes

The before render reproduces clipped/overflowing labels and the instruction card's narrow text column. The after render preserves the same typography and colors, reflows the instruction card on a narrow viewport, and scrolls labels only while they exceed their available width. The Model ID label fits in this capture, so its before/after appearance remains unchanged.

## Comparisons

1. `01-model-name.png` — localized model name label; the playable preview shows the horizontal reveal.
2. `02-model-id.png` — Model ID label, which remains static while fully visible.
3. `03-custom-parameters-heading.png` — custom parameter heading and add action.
4. `04-support-setting-cards.png` — both instruction and streaming settings, each with a side-by-side before/after card.
5. `05-audio-trim-section.png` — TrimSection title and its existing content.

`model-name-reveal.webm` is a 5.9-second preview from the rendered app at the same viewport and text scale. It shows the one-second initial pause followed by the constrained label moving to reveal the clipped end.

## Regression coverage

`tests/pages/settings/provider_model_config_constrained_text_test.dart` checks de, es, and pt-BR in light and dark themes at widths 280, 320, and 360 pixels. Width 280 uses 2.0 text scale; the other widths use 1.7. The 18 combinations passed.
