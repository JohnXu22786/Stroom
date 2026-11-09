import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
  final window = JSObject.fromInteropObject(html.window);
  final previous = window[sequenceKey]?.dartify();
  final sequence = (previous is num ? previous.toInt() : 0) + 1;
  window[sequenceKey] = sequence.toJS;
  return sequence;
}
