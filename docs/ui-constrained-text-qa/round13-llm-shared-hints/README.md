# Round 13 LLM shared field hints

The screenshots are Flutter-rendered captures of the production `LabeledTextField` and `LlmToggleTextField` widgets using localized model-name, max-token, and seed hints. The matching regression is `tests/qa/round13_llm_shared_hints_capture_test.dart`.

| Capture | Conditions | Measurement |
|---|---|---|
| `llm-hints-en-1200x800-scale1-light.png` | 1200 × 800 logical px, en-US, 1× text scale, Material 3 light theme | The three hints fit in 1136, 1112, and 1112 dp slots. Intrinsic widths are 236.1, 142.0, and 123.0 dp; each remains stationary. |
| `llm-hints-de-DE-320x1200-scale2_5-light.png` | 320 × 1200 logical px, de-DE, 2.5× text scale, Material 3 light theme | Intrinsic widths are 634.4, 352.2, and 306.3 dp in 256, 232, and 232 dp slots. All three hints clip and reveal through the existing constrained hint behavior. |
| [`llm-seed-hint-de-DE-320x640-scale2_5-light.png`](llm-seed-hint-de-DE-320x640-scale2_5-light.png) and [`dark`](llm-seed-hint-de-DE-320x640-scale2_5-dark.png) | 320 × 640 logical px, de-DE, 2.5× text scale, Material 3 light and dark themes | The seed hint has a 306.3 dp intrinsic width in a 232 dp slot. The test also checks focused and disabled hint styles against each theme's color scheme. |

[Play the 12-second seed hint reveal preview](llm-seed-hint-motion-de-DE-320x640-scale2_5-light.webm). The preview uses the same 320 × 640, de-DE, 2.5× light-theme state. It includes the one-second start delay, full outbound movement, and two-second endpoint pause; it may also show the beginning of the return.

The test checks that the complete localized hint remains in field semantics and that entering text still edits the native `TextField` controller. The screenshots use local fixture strings only; no provider request or persistence occurs.

Regenerate the screenshots and motion preview with:

```sh
flutter test --no-pub --update-goldens tests/qa/round13_llm_shared_hints_capture_test.dart
CAPTURE_ROUND13_HINT_FRAMES=1 flutter test --no-pub --no-track-widget-creation --concurrency=1 --update-goldens tests/qa/round13_llm_shared_hints_capture_test.dart --plain-name 'captures fitting and clipped LLM basic field hints'
ffmpeg -y -framerate 5 -i docs/ui-constrained-text-qa/round13-llm-shared-hints/frames/frame-%02d.png -c:v libvpx-vp9 -crf 34 -b:v 0 -pix_fmt yuv420p docs/ui-constrained-text-qa/round13-llm-shared-hints/llm-seed-hint-motion-de-DE-320x640-scale2_5-light.webm
```

The generated `frames/` directory is temporary and can be removed after encoding.
