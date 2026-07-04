import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// 原生平台的 SSE 流式客户端
/// 使用 Dio ResponseType.stream（在原生平台有效）
Stream<String> sseStream(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
  /// Callback invoked with the initial HTTP response headers, if available.
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
}) async* {
  final dio = Dio(BaseOptions(
    headers: headers,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  try {
    final response = await dio.post(
      url,
      options: Options(responseType: ResponseType.stream),
      data: body,
      cancelToken: cancelToken,
    );

    onResponseHeaders?.call(response.headers.map);

    final rawStream = response.data.stream as Stream<Uint8List>;
    final lineStream = rawStream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.startsWith('data: ')) {
        // Yield the raw SSE line; the caller (chat_api_provider.dart)
        // strips the prefix, parses JSON, and handles content/reasoning/tool_calls.
        yield line;
      }
    }
  } on DioException catch (e) {
    // Rethrow the original DioException so that upstream code
    // (chat_api_provider.dart) can capture response data and status code.
    rethrow;
  }
}
