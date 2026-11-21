# Context management field labels

The screenshot shows the production context management settings route at
320 × 640 CSS pixels, device-pixel ratio 1, normal 1× text, German (`de-DE`),
and the blue-seeded Material 3 light theme. The model's independent token
field is enabled, focused, and contains `48000`.

- [Production route, focused at 1×](context-management-de-320x640-1x-light-focused.png)
- [Playable clipped-label preview at 1.5×](threshold-label-reveal-de-320x640-1_5x.webm)

At 1×, the German field label fits and remains stationary. The WebM uses the
same production field and local model fixture at 1.5× text scale, where the
label clips and reveals horizontally; the typed value stays still. The capture
harness is `tool/qa/context_management_labels_capture.dart`. It makes no
provider request. Desktop Chromium does not show a software keyboard; the
focused outline, caret, and typed value document the keyboard state.

The focused widget test in `tests/pages/settings/settings_page_test.dart`
checks both localized labels use measured one-line slots and that the native
token input retains focus, text, and a non-end selection while the label is
allowed to animate.
