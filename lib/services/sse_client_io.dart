import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// 原生平台的 SSE 流式客户端
/// 使用 Dio ResponseType.stream（在原生平台有效）
Stream<String> sseStream(String url, Map<String, String> headers, String body,
    {CancelToken? cancelToken}) async* {
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
    final statusCode = e.response?.statusCode ?? 0;
    final errBody = e.response?.data;
    String detail;
    if (errBody is Map) {
      detail = errBody['error'] is Map
          ? '${errBody['error']['message'] ?? errBody}'
          : '$errBody';
    } else if (errBody is String) {
      detail = errBody;
    } else {
      detail = '$errBody';
    }
    throw Exception('API 请求失败 (HTTP $statusCode): $detail');
  }
}
