# OCR instruction editor label QA

The screenshot and playable preview show the production `_InstructionEditorDialog` opened from `OcrInstructionManageDialog`, at a 320 × 640 CSS-pixel viewport, DPR 1 and 1× text scale. They use the app's German (`de-DE`) localization and light Material 3 color scheme. A local fixture supplies one saved instruction; it makes no provider or network request.

- [Focused editor screenshot, 320 × 640, 1×](ocr-instruction-editor-de-320x640-1x-light.png)
- [Clipped name-label reveal preview, 1×](ocr-instruction-label-reveal-de-320x640-1x.webm)

The empty name field is focused in both captures. The localized name label, `Name der Anweisung (optional)`, exceeds its field slot and moves within it. The content label, `Inhalt der Anweisung`, fits and stays stationary. The actual text fields remain editable native `TextField`s. The screenshot shows the name field's focused outline. The browser is desktop Chromium in headless mode, so no software keyboard is present; the field was focused with a pointer click.

Capture method: a temporary Flutter Web fixture entrypoint rendered the production dialog in a Flutter 3.47.9 release build, then headless Chromium captured the 320 × 640 page at device scale factor 1. The temporary entrypoint was removed after capture. The 10.8-second WebM begins with the focused field before reveal motion and includes the label moving between its actual text endpoints. Chromium reported no console or page errors.

These captures were regenerated after the shared `ConstrainedText` update in PR #2097 was merged. The name label still reveals its clipped text, and the fitting content label remains stationary.
