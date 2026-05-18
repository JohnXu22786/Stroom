import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            if (delta != null) {
              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          }
        } catch (e) {
          debugPrint('sse_client_io: failed to parse SSE chunk: $e');
        }
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
