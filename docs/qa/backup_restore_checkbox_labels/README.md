# Backup and Restore category label QA

`comparison_category_checkbox_row.png` is one same-location side-by-side comparison. The full viewport captures are included for context; the short WebM preview shows the candidate label moving inside its constrained row.

| Condition | Value |
|---|---|
| Baseline | `origin/main` at `f0b630e5b923d270afac9a0c3dbbeccd3c420b86` |
| Candidate | Backup Restore audit branch based on the same commit |
| Viewport | 360 × 800 CSS px, device scale factor 1 |
| Locale | German (`de`, using the German locale strings) |
| Text scale | 1.7× |
| Theme | Material 3 light |
| State | Backup and Restore category list, scrolled to the checkbox rows; keyboard closed |
| Renderer | Flutter 3.47.9 release web build served locally, Chromium with SwiftShader |

A baseline WidgetTest and debug browser render found horizontal `RenderFlex` overflow in the shared `CheckboxListTile` title row at de-DE, 360 px, 1.7× (up to 502 px). The row places a leading icon and localized title beside the checkbox, with an optional info action in one caller. The candidate constrains only the title's flexible slot with `ConstrainedText`; complete localized text stays available, subtitles continue to wrap, and existing checkbox/info control placement is preserved. The candidate's 320/360 px matrix reports no layout exceptions across German and pt-BR in light and dark themes.

- [Category checkbox row comparison](comparison_category_checkbox_row.png)
- [Playable motion preview](motion_preview.webm)
- Full captures: `before_360x800_de-scale1.7_light.png` and `after_360x800_de-scale1.7_light.png`

The focused regression is `tests/pages/backup_restore_constrained_text_test.dart`.
