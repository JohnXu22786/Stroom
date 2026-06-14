/// Conditional export for thumbnail generation.
/// - Web: uses dart:js_interop for blob URL creation
/// - Native: stub implementation
export 'web_thumbnail_stub.dart'
    if (dart.library.js_interop) 'web_thumbnail.dart';
