# Provider settings overflow captures

The two composites pair matched captures from the production
`showProviderSettingsPanel` dialog before and after the layout change:

- `provider-settings-footer-before-after.png`: de-DE and pt-BR, 360 × 1200
  logical pixels, 1× scale. Each row pairs the same footer crop.
- `provider-settings-custom-header-before-after.png`: de-DE, 800 × 1200
  logical pixels, 1× scale, with the Parameter Settings tab scrolled to the
  custom-parameter heading and add action.

Both renders use the same Material light theme, localized dialog, LLM provider
fixture, default text scale, and Roboto font. The before captures came from
`origin/main` at `a2c25d8`; the after captures came from the fixed worktree.
Only the changed row is shown in each composite. The responsive widget test
exercises the same locale and width combinations and confirms no layout
exception remains.
