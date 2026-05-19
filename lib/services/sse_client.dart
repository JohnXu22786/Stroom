// 条件导出：web 平台用 sse_client_web.dart，其他平台用 sse_client_io.dart
export 'sse_client_io.dart' if (dart.library.html) 'sse_client_web.dart';
