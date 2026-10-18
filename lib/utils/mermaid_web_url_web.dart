import 'dart:html' as html;
import 'dart:js_util' as js_util;

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

/// Returns the next sequence shared with the Mermaid iframe's parent page.
int? get mermaidZoomInputSequence {
  const sequenceKey = '__stroomMermaidZoomInputSequence';
  final previous = js_util.getProperty<num?>(html.window, sequenceKey) ?? 0;
  final sequence = previous.toInt() + 1;
  js_util.setProperty(html.window, sequenceKey, sequence);
  return sequence;
}
