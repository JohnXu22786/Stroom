# Batch rename dialog constrained-label QA

Each `comparison_*.png` is a single side-by-side before/after image of one changed UI location. The paired captures use the same Flutter Web viewport, locale, text scale, theme, and dialog state. Full-screen captures are retained for context, and the short WebM preview shows the candidate dialog after it has loaded.

| Condition | Value |
|---|---|
| Baseline source | `ad481ab81029ea7adfc2237ec97b3b89db43ca9e`; `lib/widgets/batch_rename_dialog.dart` is unchanged at latest `main` `4892675c9ab63af71662329ab8af0f0c27cdce84` |
| Candidate source | Current branch implementation and QA test; the screenshots were captured after applying this branch's UI changes |
| Viewport | 360 × 800 CSS px, device scale factor 1 |
| Locale | Brazilian Portuguese (`pt-BR`) |
| Text scale | 1.7× |
| Theme | Material 3 light |
| State | Batch rename dialog open, preview tab selected, long file names loaded |
| Renderer | Flutter 3.47.9 / Dart 3.13.7, Chromium headless with SwiftShader |

The baseline test capture reported horizontal `RenderFlex` overflow in the preset load trigger, preview filter dropdown, preview scope trigger, and footer actions. The candidate gives those text slots finite flexible bounds and displays localized strings through `ConstrainedText`; it preserves the Cancel left / Apply right alignment. Existing editable file-name fields remain native `TextField`s. Candidate capture has no corresponding horizontal flex overflow.

- [Preset load trigger](comparison_preset_load.png)
- [Preview filter dropdown](comparison_preview_filter.png)
- [Preview scope trigger](comparison_preview_scope.png)
- [Footer actions](comparison_footer_actions.png)
- [Candidate motion preview](motion_preview.webm) — 5.5 seconds, trimmed from the rendered interaction after the app loaded

The full-screen matched captures are `before_360x800_pt-BR_scale-1.7_light.png` and `after_360x800_pt-BR_scale-1.7_light.png`.

`tests/widgets/batch_rename_dialog_localization_test.dart` checks German and Brazilian Portuguese at 360 px and 900 px widths, 1× and 2× text scale, and light and dark themes. It asserts the dialog receives the requested text scale, checks horizontal `RenderFlex` child bounds, and verifies there are no layout exceptions. The focused dialog, workbench, and localization widget suites pass.
