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
  } on DioException catch (_) {
    // Rethrow the original DioException so that upstream code
    // (chat_api_provider.dart) can capture response data and status code.
    rethrow;
  }
}

/// 建立持久的 SSE GET 连接（用于标准 MCP SSE 协议）。
/// 返回一个流，每一行都是一条 SSE 事件（完整行，含 event / data 前缀）。
/// 调用方需要自己解析 event 和 data 行。
Stream<String> sseConnect(
  String url,
  Map<String, String> headers, {
  CancelToken? cancelToken,

  /// Callback invoked with the initial HTTP response headers, if available.
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
}) async* {
  final dio = Dio(BaseOptions(
    headers: headers,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout:
        const Duration(seconds: 0), // No timeout for persistent connection
  ));

  final response = await dio.get(
    url,
    options: Options(responseType: ResponseType.stream),
    cancelToken: cancelToken,
  );

  onResponseHeaders?.call(response.headers.map);

  final rawStream = response.data.stream as Stream<Uint8List>;
  final lineStream = rawStream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lineStream) {
    // Yield ALL lines (event names, data, empty lines) so the caller
    // can parse the full SSE protocol (event: endpoint, data: ...)
    yield line;
  }
}

/// 向 MCP 消息端点发送 JSON-RPC POST 请求。
/// 直接返回响应体字符串（非流式）。
Future<String> ssePost(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
}) async {
  final dio = Dio(BaseOptions(
    headers: headers,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final response = await dio.post(
    url,
    data: body,
    cancelToken: cancelToken,
  );
  return response.data?.toString() ?? '';
}
