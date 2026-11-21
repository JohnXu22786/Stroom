# LLM endpoint selector label

These artifacts capture the production `LlmModelConfigPage` in a release Flutter
Web build at a 320 × 640 logical-pixel viewport and 1× device scale. The page
uses a local `ModelConfig` fixture with the OpenAI-compatible endpoint enabled;
no provider credentials or endpoint requests are used. The build bundles
Flutter's web renderer locally (`flutter build web --release --no-pub
--no-web-resources-cdn --target=tools/qa/llm_endpoint_selector_capture.dart`),
and Chromium blocked external requests during capture; none were attempted.

- `fr-endpoint-selector-320x640-1x.png` shows the localized French field label
  and selected endpoint value in the light theme.
- `fr-endpoint-selector-menu-open-320x640-1x.png` shows the selector open. Its
  long first option is clipped to the narrow menu row.
- `fr-endpoint-selector-focus-320x640-1x.png` shows the native dropdown focused
  after opening it and dismissing the menu with Escape. The field label remains
  visible and the focus outline is retained.
- `en-endpoint-selector-320x640-1x.png` shows the short English field label
  fitting in the same selector.
- `endpoint-option-label-reveal.webm` is a playable preview of the clipped
  first menu option moving horizontally while the selector remains open.

Captures use the light theme and 1× text scale. Keyboard state is desktop
Chromium: the popup was opened with a pointer and dismissed with Escape; no
software keyboard is present. The fixture and query parameters are in
`tools/qa/llm_endpoint_selector_capture.dart` (`locale=en|fr`,
`theme=light|dark`, and `scale=<number>`). The screenshots and preview were
rendered from that harness against the production page implementation.
