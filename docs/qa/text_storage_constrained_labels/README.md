# Text storage constrained field labels

Captures use the production `TextCreatePage` at 320 × 640 logical pixels and 1× device scale, in Portuguese (Brazil) with the app's blue-seeded Material 3 light theme. Both captures show an unsaved draft titled `Rascunho` with the title field focused. Headless Chromium does not display a software keyboard; the title field remains a native editable input. No save or network request is made.

- [Normal text scale screenshot](text-storage-pt-br-320x640-1x-light-focused.png): all three localized labels fit and remain stationary.
- [Play the clipped field-label reveal](text-storage-pt-br-content-label-2_5x-320x640-light.webm): at 2.5× text scale, the content and format labels reveal within their field slots while the typed title remains stationary.

The capture entrypoint is [`tool/qa/text_storage_capture.dart`](../../../tool/qa/text_storage_capture.dart); its `scale` query parameter selects the text scale. The focused widget test covers native editing and selection, fitting labels, and a localized field label clipped by its actual production slot. `tests/widgets/constrained_text_test.dart` covers the shared fitting and motion behavior.
