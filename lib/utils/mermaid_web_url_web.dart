import 'dart:html' as html;

Uri get mermaidWebBaseUri =>
    Uri.parse(html.document.baseUri ?? html.window.location.href);

double get mermaidZoomInputTimestamp {
  final performance = html.window.performance;
  final timeOrigin = performance.timeOrigin;
  if (timeOrigin != null) {
    return timeOrigin + performance.now();
  }
  return DateTime.now().microsecondsSinceEpoch / 1000.0;
}
