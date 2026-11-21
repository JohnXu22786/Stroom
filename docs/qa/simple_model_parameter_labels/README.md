# Simple model parameter field labels

The screenshot and playable preview show the production `SimpleModelConfigPage` with one existing custom parameter at a 320 × 640 CSS-pixel viewport, DPR 1, 1× text scale, German (`de-DE`) localization, and the light Material 3 theme. The `Parametername` field is pointer-focused; its outlined border and caret show the focus state. The desktop Chromium capture has no software keyboard. Both parameter inputs remain native editable `TextFormField`s and retain their current values.

- [Focused parameter editor, 320 × 640, 1×](parameter-label-de-320x640-1x-light-focused.png)
- [Playable German label reveal](parameter-label-reveal-de-320x640-1x.webm)

The preview records the actual clipped `Parametername` label moving inside the finite name-field slot. No provider request or network call was made. The temporary Flutter Web entrypoint used a local `ModelConfig` fixture and was removed after capture. The focused widget test checks both localized labels reveal in the narrow layout and verifies the parameter field remains focused and editable. The shared `ConstrainedText` widget test covers fitting text remaining stationary.
