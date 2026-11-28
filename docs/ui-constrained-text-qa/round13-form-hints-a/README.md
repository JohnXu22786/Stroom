# Round 13 native form hint captures

These captures come from the production `SimpleModelConfigPage`.

| Capture | Viewport | Locale | Text scale | Theme | Evidence |
|---|---:|---|---:|---|---|
| [model-id-fitting-en-1200x800-scale1-light.png](model-id-fitting-en-1200x800-scale1-light.png) | 1200 × 800 logical px | en-US | 1× | Light | Model ID example hint measures 1136 × 24 px and fits without motion. |
| [custom-json-clipped-de-320x640-scale1_8-light.png](custom-json-clipped-de-320x640-scale1_8-light.png) | 320 × 640 logical px | de-DE | 1.8× | Light | Focused native JSON value field shows the localized example in its measured 232 × 43 px slot. |
| [custom-json-clipped-de-320x640-scale1_8-dark.png](custom-json-clipped-de-320x640-scale1_8-dark.png) | 320 × 640 logical px | de-DE | 1.8× | Dark | Same focused field and clipped hint in the dark theme. |

The field remains a native `TextFormField`. The capture test measures the rendered hint slot, verifies the fitting hint remains stationary, and confirms the localized JSON hint is clipped. Its Flutter widget-test captures are `custom-json-clipped-de-320x640-scale1_8-widget-test-light.png` and `custom-json-clipped-de-320x640-scale1_8-widget-test-dark.png`.

## Motion preview

[custom-json-hint-reveal-de-320x640-scale1_8-light.webm](custom-json-hint-reveal-de-320x640-scale1_8-light.webm) is a 10-second, 8 fps capture of the production page. It shows the one-second initial still period, the hint moving to its measured endpoint, the endpoint pause, and the return movement. Both the light preview and dark capture use a 320 × 640 CSS-pixel viewport, DPR 1, de-DE locale, and 1.8× text scale. Recreate the browser artifacts with `python3 tools/qa/capture_round13_form_hints.py`.
