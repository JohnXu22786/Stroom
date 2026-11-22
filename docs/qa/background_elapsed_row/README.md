# Background task elapsed row QA

The source screenshots show the real `BackgroundTaskCard` Flutter component rendered through a temporary Flutter Web harness. The harness was removed after capture.

| Condition | Value |
|---|---|
| Baseline | `baab36dd90f4302123bbef2fc953f3e28b0c1f1b` (`origin/main`) |
| Viewport | 360 × 800 CSS px, device scale factor 1 |
| Locale | German (`de-DE`) |
| Text scale | 1.7 |
| Theme | Material 3 light |
| State | Running task, card header collapsed |
| Renderer | Flutter 3.47.9 / Dart 3.13.7, Chromium 154.0.8037.57 |

The before capture reported a 173 px right-side `RenderFlex` overflow in the metadata row. The after capture shows the status chip, relative timestamp, and live elapsed label wrapping onto additional lines with no overflow. The leading sync icon remains at the original header position (about 1 px center-position difference in the two captures) as the card grows. Both captures use the same viewport, locale, scale, theme, card state, and task setup. The elapsed text is live and can differ as seconds pass. The side-by-side image is cropped to the card area and labeled; the two full viewport captures are retained below.

- [Before](before_360x800_de-DE_scale-1.7_light.png)
- [After](after_360x800_de-DE_scale-1.7_light.png)
- [Side-by-side comparison](comparison_before-after_360x800_de-DE_scale-1.7_light.png)
