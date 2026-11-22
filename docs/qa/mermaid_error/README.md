# Mermaid render error screenshots

These captures show the production `MermaidRenderWidget` rendered by Flutter's
CanvasKit renderer in headless Chromium, not a widget-test image or a mock
component drawing.

Capture conditions: 320 × 640 CSS pixels, device scale factor 1, text scale 1,
`en-US`, light theme. The long-error widget is 500 dp high with a horizontal
16 dp margin. The compact widget is 112 dp high and centered in the same
viewport. The long message is a deterministic simulated WebView diagnostic
injected through the widget's `@visibleForTesting` initial-error hook because
the web plugin does not forward JavaScript error callbacks in Chrome. The
short message uses the same injection hook. The error overlay, scroll view,
Retry button, and toolbar are the production component UI.

- [`mermaid-error-long-top-320x640.png`](mermaid-error-long-top-320x640.png): initial scroll position with the diagnostic extending below the viewport.
- [`mermaid-error-long-scrolled-320x640.png`](mermaid-error-long-scrolled-320x640.png): after scrolling the detail; scrolled diagnostic detail and Retry are visible while the toolbar stays at the top.
- [`mermaid-error-short-top-320x640.png`](mermaid-error-short-top-320x640.png): compact 112 dp error overlay with the toolbar and the existing short-message layout.

Capture method: `flutter build web --release --target=tool/qa/mermaid_error_capture.dart`, serve `build/web`, then open it in Chromium 154 with a 320 × 640 viewport and device scale factor 1. Scroll the long-error page to reveal the remainder of its detail. The compact case is available with `?compact=1`; scrolling the widget reaches Retry. The build reports CanvasKit as its renderer.
