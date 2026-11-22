# Assistant defaults preview heading QA

The assistant defaults preview heading uses an expanded `ConstrainedText` slot beside its visibility icon. It keeps the existing 13 px semibold style and text alignment while leaving enough room for short labels to render in full. The real settings tab was rendered in a dialog-sized panel at a 320 × 640 CSS viewport and device pixel ratio 1.

## Captures

- `preview-heading-zh-320x640-1x.png` — short Chinese heading, fitting in its row.
- `preview-heading-pt-overflow-320x640-1x.png` — longer Portuguese heading after horizontal reveal begins.
- `preview-heading-pt-overflow-320x640-1x-motion.webm` — playable Portuguese heading reveal.

The widget test checks the actual assistant edit tab at 320 × 640 for the fitting Chinese heading at 1× and the longer Portuguese heading at 1× and 2× text scale. It verifies rasterization slack for the fitting title, confirms that it stays still, checks that clipped text moves, and keeps the icon and existing model/tool controls within their slots without layout exceptions.

Captures use a Flutter 3.47.9/Dart 3.13.7 release Web build and headless Chromium with the production `AssistantDefaultsTab` widget inside its dialog-sized scroll panel. The temporary capture entrypoint was removed after generating the screenshots and preview. Chromium reported no page or console errors.
