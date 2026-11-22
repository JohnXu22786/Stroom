# LLM account dropdown label QA

The captures show Stroom's production `ConstrainedText` widget inside the same `DropdownButtonFormField` pattern used by the LLM account and model group editors. Synthetic local account and model labels exercise clipped selected values and shorter menu choices; the fixture makes no account, credential, or network request.

- [320 × 640 production component screenshot](account-dropdowns-fr-320x640-scale1-light.png)
- [Open dropdown menu showing both clipped and fitting options](account-dropdown-menu-fr-320x640-scale1-light.png)
- [Play the clipped-label motion preview](account-dropdown-motion-preview.webm)

The stills use a 320 × 640 CSS-pixel viewport at DPR 1, French (`fr-FR`), Material 3 light theme, and 1× text scale. The primary screenshot has no focused field or software keyboard. The supplemental screenshot has the account dropdown open with that control focused; the software keyboard remains closed. Motion is disabled in both stills so clipped labels remain at their initial positions. The preview uses normal motion and plays at 8 fps for 16 seconds.

To recreate the artifacts, build the fixture with `flutter build web --release --no-pub --target tools/qa/llm_account_dropdown_capture.dart --output /tmp/llm-account-dropdown-web --no-wasm-dry-run`, serve it with `python3 -m http.server 8879 --directory /tmp/llm-account-dropdown-web`, then run `python3 tools/qa/capture_llm_account_dropdowns.py`.
