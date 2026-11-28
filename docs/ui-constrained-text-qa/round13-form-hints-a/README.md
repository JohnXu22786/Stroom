# Round 13 native form hint captures

These captures come from the production `SimpleModelConfigPage`.

| Capture | Viewport | Locale | Text scale | Theme | Evidence |
|---|---:|---|---:|---|---|
| [model-id-fitting-en-1200x800-scale1-light.png](model-id-fitting-en-1200x800-scale1-light.png) | 1200 × 800 logical px | en-US | 1× | Light | Model ID example hint measures 1136 × 24 px and fits without motion. |
| [custom-json-clipped-de-320x640-scale1_8-light.png](custom-json-clipped-de-320x640-scale1_8-light.png) | 320 × 640 logical px | de-DE | 1.8× | Light | JSON default-value hint measures 232 × 43 px; the localized example exceeds its one-line slot. |

The field remains a native `TextFormField`. The capture test measures the rendered hint slot and verifies that the fitting hint remains stationary while the localized JSON hint is recognized as clipped.
