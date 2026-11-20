# Assistant tool output limit label QA

The production `AssistantDefaultsTab` was rendered in Chromium at a 320 × 640 CSS viewport and device pixel ratio 1, using Portuguese (Brazil), the default 5,000 character limit, and truncation enabled.

- `assistant-tool-output-pt-320x640-1x.png` — the production field's short label fits and stays still at the default text scale.
- `assistant-tool-output-pt-320x640-1x-long-fixture.png` — production tab after the helper changed to unlimited natural wrapping. Its actual short label stays still and its helper wraps; a separate QA-only long-label fixture below it demonstrates clipped-label motion.
- `assistant-tool-output-long-label-motion-320x640-1x.webm` — playable 12-second capture of the QA-only fixture moving in the same `ConstrainedText` input-label slot.

The widget test exercises the production field's blank, focused keyboard, invalid-range, valid-value, and 3× text-scale states. It asserts that the localized helper wraps to more than two lines at the scaled narrow viewport, with no fixed line cap. Existing `ConstrainedText` tests cover delayed motion for clipped labels and stationary fitting labels. Chromium reported no page or console errors for the captures.

The capture fixture uses the production `AssistantDefaultsTab` with the real Portuguese localization resources, a 5,000-character initial value, truncation enabled, and no configured default model or tools. The extra fixture text is explicitly labeled QA-only and is not a production translation. A temporary Web entrypoint was removed after capture.
