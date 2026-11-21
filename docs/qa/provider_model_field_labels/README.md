# Provider model field labels

These captures use the production `ModelConfigPage` at 320 × 640 logical px,
1× device scale, with native Flutter text rendering. They show the numeric
TTS range and maximum audio length fields in the add-model state.

- `model-fields-en-320x640-1x-light-focused.png` shows the English minimum
  volume label fitting in its field, in the light theme with the field focused.
- `model-fields-de-320x640-1x-dark-focused.png` shows German labels that clip
  in the narrow range fields, in the dark theme with the field focused.
- `model-fields-de-320x640-1x-light-reveal.webm` is a playable production-page
  preview of the clipped labels moving while the field remains focused.

The capture app is `tools/qa/provider_model_field_labels_capture.dart`. It
mounts `ModelConfigPage` with an empty local provider entry; no network or
provider request is made. `?locale=en|de`, `?theme=light|dark`, and `?scale=2`
select the capture state. The regression test checks localized TTS field labels
at 320 × 640 and 1.8× text scale, then enters text into a native editable field
and confirms focus and value are retained.
