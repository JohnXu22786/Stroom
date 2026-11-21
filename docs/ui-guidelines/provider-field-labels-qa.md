# Provider field label QA capture

These artifacts show the production `ProviderSettingsPanel` component in Flutter Web release mode, rendered by Chromium. A temporary local entrypoint opened the real `showProviderSettingsPanel` with a local provider configuration; no test font, mock field, or provider network request was used.

## Capture state

- Viewport: 320 × 640 logical pixels at device scale factor 1.
- Locale: Portuguese (Brazil), `pt-BR`.
- Theme: light Material 3; system text scale 1.0; reduced motion not requested.
- Screen: provider settings, “Configuração de parâmetros” tab, scrolled to the reasoning toggle fields.
- Focus and editing: the “Valor quando desativado” field is focused and contains `false`; Chromium's Flutter text input host is active and the caret is visible. Desktop Chromium has no on-screen software keyboard.
- Label behavior: the longer on/off labels are clipped by their measured finite field slots and reveal horizontally. “Nome do parâmetro” fits and remains stationary. The preview begins with the narrow viewport after a resize from 1200 × 800, so it includes the initial still interval before movement and the endpoint pause.

## Artifacts

![Provider parameter fields at 320 × 640, with a clipped localized field label and a fitting stationary label](images/provider-field-labels-320x640-pt-BR.png)

[Play the 9-second clipped-label motion preview](images/provider-field-label-motion-320x640-pt-BR.webm)
