# Text storage constrained field labels

Captures use the production `TextCreatePage` at 320 × 640 logical pixels and 1× device scale, in Portuguese (Brazil) with the app's blue-seeded Material 3 light theme. Both captures show an unsaved draft titled `Rascunho` with the title field focused. Headless Chromium does not display a software keyboard; the title field remains a native editable input. No save or network request is made.

- [Normal text scale screenshot](text-storage-pt-br-320x640-1x-light-focused.png): all three localized labels fit and remain stationary.
- [Play the clipped field-label reveal](text-storage-pt-br-content-label-2_5x-320x640-light.webm): at 2.5× text scale, the content and format labels reveal within their field slots while the typed title remains stationary.

The capture entrypoint is [`tool/qa/text_storage_capture.dart`](../../../tool/qa/text_storage_capture.dart); its `scale` query parameter selects the text scale. The focused widget test covers native editing and selection, fitting labels, and a localized field label clipped by its actual production slot. `tests/widgets/constrained_text_test.dart` covers the shared fitting and motion behavior.

## Text Storage top actions

These additional captures use the production `TextStoragePage` in a Flutter web
release build, with French localization and an empty local text store. The
browser viewport is 320 × 640 CSS px for narrow captures and 800 × 640 CSS px
for wider captures, at DPR 1. Motion is reduced for stable screenshots.

They cover both themes and 1×/4× text scale at both widths. At 1×, the top
action controls retain their 48 dp height. At 4×, they grow to fit the scaled
labels while retaining their icons, action labels, horizontal arrangement, and
spacing:

- `text-storage-actions-narrow-1x-light.png`
- `text-storage-actions-narrow-1x-dark.png`
- `text-storage-actions-narrow-4x-light.png`
- `text-storage-actions-narrow-4x-dark.png`
- `text-storage-actions-wide-1x-light.png`
- `text-storage-actions-wide-1x-dark.png`
- `text-storage-actions-wide-4x-light.png`
- `text-storage-actions-wide-4x-dark.png`

At 4× scale, the narrow static screenshots keep reduced motion enabled, so the
existing horizontal overflow appears in its stationary ellipsis state. The
[12-second production reveal](text-storage-actions-narrow-4x-dark-reveal.webm)
uses normal motion and records the French 4× dark `TextStoragePage` at 320 × 640
CSS px; both action labels move through their existing horizontal reveal.

Rebuild and capture them with:

```sh
python3 tool/qa/capture_text_storage_actions.py
```
