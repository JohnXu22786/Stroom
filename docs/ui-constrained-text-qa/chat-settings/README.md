# Chat settings sheet heading QA

The chat settings sheet headings sat in a fixed horizontal row beside a 28 px
icon and an 10 px gap. In German at 320 × 640 and 1.8× text scale, the
reasoning heading `Einstellungen zum Denkprozess` caused a 592 px right-side
`RenderFlex` overflow. The four model, tools, reasoning, and custom-parameter
sheet headings now use a flexible one-line `ConstrainedText` slot. Fitting text
remains static; clipped text starts its existing horizontal reveal after the
shared component's delay. Icons, title styling, and semantics are preserved.

## Captures

- [German reasoning sheet, 320 × 640, 1.8× text, light theme](reasoning-de-320x640-scale1_8-light.png) shows the long heading during its reveal, alongside the naturally wrapping reasoning settings content.
- [Chinese reasoning sheet, 430 × 932, 1× text, dark theme](reasoning-zh-430x932-scale1-dark.png) shows a fitting heading at rest.
- [German heading reveal preview](reasoning-de-heading-motion.webm) is a 7.2-second Chromium capture at 320 × 640, 1.8× text, and light theme.

Captures use the production `showReasoningPanel`, generated app localizations,
and Material theme in Chromium. A temporary isolated QA entrypoint was removed
after capture. No remote model or provider requests were made.

## Validation

`tests/pages/chat/composer/chat_setting_panels_reasoning_test.dart` reproduces
the German narrow-width/large-text case, verifies the heading's natural width
exceeds its allocated slot, and checks that the sheet lays out without a
rendering exception. With the old unconstrained `Text`, this same case reported
the 592 px `RenderFlex` overflow.
