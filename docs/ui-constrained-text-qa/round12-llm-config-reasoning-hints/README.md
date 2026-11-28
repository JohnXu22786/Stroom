# Round 12 LLM model reasoning hints

This capture uses the production `LlmModelConfigPage` route with local provider fixtures. No account data, provider calls, or persistent changes are involved. The viewport is 320 × 640 logical px at DPR 1, German (`de-DE`), 2× text scale, Material 3 light. The native on-value field is focused; the software keyboard is not drawn by Flutter widget captures.

The on-value example has a 94 × 48 dp one-line slot. The complete localized hint exceeds the slot, so `ConstrainedInputHint` reveals it while the editor remains a native `TextFormField`. The regression checks the screen reader hint before and after native typing. JSON examples remain native five-line fields and use the same measured hint component.

- [Focused on-value hint](reasoning-toggle-value-de-320x640-scale2-light.png)
- [Effort add-value dialog hint](effort-add-value-dialog-de-320x640-scale2-light.png)
- [8-second scroll preview (320 × 640, 5 fps)](reasoning-hint-scroll-preview.webm)

Capture and measurement test:

```sh
flutter test --no-pub --no-track-widget-creation --concurrency=1 tests/qa/round12_llm_model_reasoning_hints_capture_test.dart --plain-name 'captures clipped model reasoning parameter example hints'
```

Regenerate the motion preview frames and video:

```sh
CAPTURE_ROUND12_HINT_FRAMES=1 flutter test --no-pub --no-track-widget-creation --concurrency=1 --update-goldens tests/qa/round12_llm_model_reasoning_hints_capture_test.dart --plain-name 'captures clipped model reasoning parameter example hints'
ffmpeg -y -framerate 5 -i docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/frames/frame-%02d.png -c:v libvpx-vp9 -crf 34 -b:v 0 -pix_fmt yuv420p docs/ui-constrained-text-qa/round12-llm-config-reasoning-hints/reasoning-hint-scroll-preview.webm
```

The test frame sequence is generated under `frames/` and can be removed after encoding.
