# Assistant defaults preview heading QA

The assistant defaults preview heading is bounded beside its visibility icon by `Flexible` and the shared `ConstrainedText`. Its localized title keeps the same 13 px semibold style. The real settings tab was rendered in a dialog-sized panel at a 320 × 640 CSS viewport and device pixel ratio 1.

## Captures

- `preview-heading-zh-320x640-1x.png` — short Chinese heading, fitting in its row.
- `preview-heading-pt-overflow-320x640-1x.png` — longer Portuguese heading after horizontal reveal begins.
- `preview-heading-pt-overflow-320x640-1x-motion.webm` — playable Portuguese heading reveal.

The widget test checks the actual assistant edit tab at 320 × 640 for the fitting Chinese heading at 1× and the longer Portuguese heading at 1× and 2× text scale. It verifies that fitting text stays still, clipped text moves, the icon retains its slot, the model/tool controls remain present, and no layout exception is raised.

Captures use a Flutter 3.47.9/Dart 3.13.7 release Web build and headless Chromium with the production `AssistantDefaultsTab` widget inside its dialog-sized scroll panel. The temporary capture entrypoint was removed after generating the screenshots and preview. Chromium reported no page or console errors.
