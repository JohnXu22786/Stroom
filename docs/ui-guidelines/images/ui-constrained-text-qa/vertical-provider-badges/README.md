# Provider badges at narrow widths

These captures use the production `ProviderConfigPage` at 320 × 640 logical
pixels, device scale 1, German locale, and light Material 3 theme. A 1000 × 640
capture shows the fitting inline layout. The fixture
contains an in-memory vendor MCP service with a long German title, a custom
MCP service, and the normal built-in tool cards. No control is focused, the
keyboard is closed, and no provider request or persistence occurs.
The static captures show the start of the one-second reveal delay: the fixture
loads at 1000 px, scrolls to the provider cards, then resizes to 320 px before
capturing so the production label measurement and still period are visible.

- `provider-badges-de-1000x640-scale1-light.png` shows all card labels and
  controls fitting in the original inline layout at a standard wide viewport.
- `provider-badges-de-320x640-scale1-light.png` shows the regular 1× state.
- `provider-badges-de-320x640-scale1_8-light.png` shows the same page at 1.8×
  text scale.
- `provider-badge-motion-preview.webm` records the clipped title revealing its
  full value inside its slot at 1.8× text scale.
- `tools/qa/vertical_provider_badges_capture.dart` supplies the safe local
  production-page fixture. `tools/qa/capture_vertical_provider_badges.py`
  captures both screenshots and the motion preview.
- `tests/pages/settings/provider_config_page_provider_badges_test.dart`
  owns the layout regressions: 320 px MCP drag reorder, 360 px compact MCP
  controls, 400/420 px inline MCP cards, and 700 px ordinary LLM inline card.
  CI routes it uniquely to the
  `chat-ai-ui` functional suite.

Build the safe fixture with `flutter build web --release --no-pub
--no-wasm-dry-run --target=tools/qa/vertical_provider_badges_capture.dart`,
serve `build/web` on port 8883, then run
`python3 tools/qa/capture_vertical_provider_badges.py`.
