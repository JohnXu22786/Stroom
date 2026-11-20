# Text storage format icon

Captured from a release Flutter web build in Chromium at a logical 320 × 640 viewport and device pixel ratio 1. The capture harness renders the production `ConstrainedText` widget inside the same 44 dp rounded icon with its production 12 px bold theme-primary style.

- [MMD fitting label, light theme, 1× text](mmd-label-light-320x640.png): the complete label stays centered and stationary.
- [YAML reveal preview, dark theme, 2× text](yaml-reveal-2x-dark.gif) ([WebM](yaml-reveal-preview.webm)): the valid `yaml` format clips at this scale, then moves inside the unchanged icon.
- [Reveal start frame](yaml-reveal-start.png) and [moving frame](yaml-reveal-moving.png), extracted from the Chromium recording.

The widget test also checks English and German locales, light and dark themes, and 1× and 2× text scales. The supported format set is `txt`, `md`, `mmd`, `json`, `xml`, `csv`, `yaml`, `yml`, `toml`, `ini`, `cfg`, `log`, and `env`.
