# Math canvas WebView error details preview

Screenshot: [`math-canvas-error-320x640-1x.png`](math-canvas-error-320x640-1x.png)

Capture configuration: 320 × 640 CSS pixels at device pixel ratio 1, `en-US` synthetic diagnostic text, the WebView component's existing fixed error styling over a transparent canvas, no focused element, and keyboard closed. No motion was added.

The screenshot uses the production HTML template from `MathCanvasWebView.buildMathHtml` with `Math.pow(x,2)` and a local synthetic parser diagnostic. It contains no user data. JSXGraph renders the real-time chart as in production; the diagnostic overlay caps at half the 640-pixel canvas height, leaving the lower chart visible. A separate browser check confirmed the diagnostic scrolls with Page Down.
