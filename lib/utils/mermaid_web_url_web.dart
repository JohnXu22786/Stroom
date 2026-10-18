import 'dart:html' as html;

Uri get mermaidWebBaseUri =>
    Uri.parse(html.document.baseUri ?? html.window.location.href);

double get mermaidZoomInputTimestamp =>
    html.window.performance.timeOrigin + html.window.performance.now();
