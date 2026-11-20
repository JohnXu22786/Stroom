# Text storage format icon

The [actual Text Storage page capture](text_storage_page-mmd-320x640-1x-light.png) is from a release Flutter web build in Chromium at a logical 320 × 640 viewport, device pixel ratio 1, and normal text scale. It renders `TextStoragePage` through `FileManagerView` and its production `fileIconBuilder`; the `Note.mmd` fixture appears in the real file grid.

The [MMD fitting-label capture](mmd-label-light-320x640.png) isolates the production 44 dp icon and `ConstrainedText` at 1× text scale; the complete label stays centered and stationary. The [YAML reveal preview](yaml-reveal-2x-dark.gif) ([WebM](yaml-reveal-preview.webm)) shows the full value moving at 2× text scale in dark theme. The [start frame](yaml-reveal-start.png) and [moving frame](yaml-reveal-moving.png) are extracted from the Chromium recording.

The widget test also checks English and German locales, light and dark themes, and 1× and 2× text scales. The supported format set is `txt`, `md`, `mmd`, `json`, `xml`, `csv`, `yaml`, `yml`, `toml`, `ini`, `cfg`, `log`, and `env`.
