# LLM endpoint selector label

These artifacts capture the production `LlmModelConfigPage` in a release Flutter
Web build at a 320 × 640 logical-pixel viewport and 1× device scale. The page
uses a local `ModelConfig` fixture with the OpenAI-compatible endpoint enabled;
no provider credentials or endpoint requests are used. The build bundles
Flutter's web renderer locally (`flutter build web --release --no-pub
--no-web-resources-cdn --target=tools/qa/llm_endpoint_selector_capture.dart`),
and Chromium blocked external requests during capture; none were attempted.

- `fr-endpoint-selector-320x640-1x.png` shows the localized French field label
  and selected endpoint value in the light theme at normal text scale. The
  field label fits at this scale.
- `fr-endpoint-selector-menu-open-320x640-1x.png` shows the selector open. Its
  long first option is clipped to the narrow menu row.
- `fr-endpoint-selector-focus-320x640-1x.png` shows the native dropdown focused
  after opening it and dismissing the menu with Escape. The field label remains
  visible and the focus outline is retained.
- `en-endpoint-selector-320x640-1x.png` shows the short English field label
  fitting in the same selector at normal text scale. It stays stationary.
- `fr-endpoint-field-label-320x640-1x-scale-180.png` shows the actual French
  endpoint field label clipped in the selector at 1.8× text scale, with the
  dropdown focused after dismissal with Escape.
- `fr-endpoint-field-label-reveal-scale-180.webm` is the playable preview of
  that clipped field label moving within its InputDecoration slot. This captures
  the field label changed by this PR.
- `endpoint-option-label-reveal.webm` is a separate preview of the clipped
  first dropdown menu option moving horizontally; it does not show the field
  label clipping.

All captures use the light theme. The supplementary field-label clipping state
uses French at 1.8× text scale; the fitting comparison uses English at 1×.
Keyboard state is desktop Chromium: the dropdown was opened with a pointer and
dismissed with Escape; no software keyboard is present. The fixture and query
parameters are in `tools/qa/llm_endpoint_selector_capture.dart`
(`locale=en|fr`, `theme=light|dark`, and `scale=<number>`). The screenshots and
preview were rendered from that harness against the production page
implementation.

The focused widget tests measure the actual localized label against its clip
slot, verify that the French label moves at 1.8×, verify that the fitting
English label stays still at 1×, and exercise the existing dropdown options and
selected value.
