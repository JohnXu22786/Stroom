# Assistant tool output limit label QA

The production `AssistantDefaultsTab` was rendered in Chromium at a 320 × 640 CSS viewport and device pixel ratio 1, using Portuguese (Brazil), the default 5,000 character limit, and truncation enabled. The capture is the narrow dialog-sized panel's scrolled state, showing the actual tools card and character limit field.

- `assistant-tool-output-pt-320x640-1x.png` — the complete label and helper remain visible at the default text scale; the label stays still when it fits.

The widget test also constrains the production tab to a narrower panel to verify that the Portuguese helper wraps, then exercises the blank, focused keyboard, invalid-range, valid-value, and 2× text-scale states. Existing `ConstrainedText` tests cover delayed motion for clipped labels and stationary fitting labels. Chromium reported no page or console errors for the captured page.

The capture fixture uses the production `AssistantDefaultsTab` with the real Portuguese localization resources, a 5,000-character initial value, truncation enabled, and no configured default model or tools. A temporary Web entrypoint was removed after capture.
