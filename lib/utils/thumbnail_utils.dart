/// Conditional export for thumbnail generation.
/// - Web: uses `dart:html` blob URL creation (dart2js target)
/// - Native: stub implementation
library;

export 'web_thumbnail_stub.dart' if (dart.library.html) 'web_thumbnail.dart';
