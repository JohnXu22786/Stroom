# Assistant import instructions

The captures show the production built-in assistant selector with its Importer tab selected, French (`fr-FR`) instructions, a 320 × 640 CSS-pixel viewport, device scale factor 1, and normal 1× text size. The light and dark screenshots use the application's existing Material color schemes. The import instruction wraps naturally and remains fully visible; the tab content stays vertically scrollable for larger text scales. The existing import action and flow are unchanged.

- [Light theme capture](import-hint-fr-320x640-1x-light.png)
- [Dark theme capture](import-hint-fr-320x640-1x-dark.png)

The focused widget regression checks the narrow import tab at 320 × 640 and verifies the hint has no line or overflow cap and the import action remains reachable in the scrollable content. No motion preview is needed for the instruction because it is no longer animated.
