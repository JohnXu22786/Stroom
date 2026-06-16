import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:stroom/providers/chat_api_provider.dart';

/// Creates a DioException with a ResponseBody (simulating streaming error).
DioException _makeStreamingDioException({
  required int statusCode,
  dynamic data,
}) {
  Response? response;
  if (data is String) {
    final bytes = utf8.encode(data);
    final stream = Stream<Uint8List>.fromIterable([Uint8List.fromList(bytes)]);
    response = Response<ResponseBody>(
      requestOptions: RequestOptions(
        path: 'http://example.com/chat/completions',
        responseType: ResponseType.stream,
      ),
      statusCode: statusCode,
      data: ResponseBody(stream, statusCode),
    );
  } else if (data is Map) {
    response = Response(
      requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
      statusCode: statusCode,
      data: data,
    );
  } else {
    response = Response(
      requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
      statusCode: statusCode,
    );
  }

  return DioException(
    type: DioExceptionType.badResponse,
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    response: response,
    message: 'Bad response',
  );
}

void main() {
  group('parseStreamErrorBody', () {
    test('reads ResponseBody stream and returns raw string', () async {
      final errorBody = '{"error":{"message":"Bad Request"}}';
      final exception = _makeStreamingDioException(
        statusCode: 400,
        data: errorBody,
      );

      final result = await parseStreamErrorBody(exception);

      expect(result, isNotNull);
      expect(result!['raw'], errorBody);
    });

    test('returns null for Map data (non-stream error)', () async {
      final exception = _makeStreamingDioException(
        statusCode: 400,
        data: {'error': {'message': 'Bad'}},
      );

      final result = await parseStreamErrorBody(exception);
      expect(result, isNull);
    });

    test('returns null when response is null', () async {
      final exception = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: 'http://example.com/api'),
        message: 'Timeout',
      );

      final result = await parseStreamErrorBody(exception);
      expect(result, isNull);
    });

    test('returns null when response data is null', () async {
      final exception = _makeStreamingDioException(
        statusCode: 400,
        data: null,
      );

      final result = await parseStreamErrorBody(exception);
      expect(result, isNull);
    });

    test('handles multiple stream chunks', () async {
      final chunk1 = '{"error":';
      final chunk2 = '{"message":"Bad"}}';
      final stream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode(chunk1)),
        Uint8List.fromList(utf8.encode(chunk2)),
      ]);
      final response = Response<ResponseBody>(
        requestOptions: RequestOptions(
          path: 'http://example.com/chat/completions',
          responseType: ResponseType.stream,
        ),
        statusCode: 400,
        data: ResponseBody(stream, 400),
      );
      final exception = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
        response: response,
      );

      final result = await parseStreamErrorBody(exception);

      expect(result, isNotNull);
      expect(result!['raw'], '{"error":{"message":"Bad"}}');
    });
  });
}
