import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/sse_client_web_error.dart';

void main() {
  group('web SSE error conversion', () {
    test('HTTP 429 remains a response error and preserves Retry-After', () {
      final error = createSseClientWebFailure(
        url: 'https://example.test/chat',
        statusCode: 429,
        statusText: 'Too Many Requests',
        responseBody: '{"error":"rate limited"}',
        responseHeaders: const {
          'retry-after': ['12'],
        },
      );

      expect(error.type, DioExceptionType.badResponse);
      expect(error.response?.statusCode, 429);
      expect(error.response?.headers.value('retry-after'), '12');
      expect(error.response?.data, '{"error":"rate limited"}');
    });

    test('HTTP server errors remain response errors', () {
      final error = createSseClientWebFailure(
        url: 'https://example.test/chat',
        statusCode: 503,
        statusText: 'Unavailable',
        responseBody: 'server error',
      );

      expect(error.type, DioExceptionType.badResponse);
      expect(error.response?.statusCode, 503);
    });

    test('XHR without an HTTP response is a connection error', () {
      final error = createSseClientWebFailure(
        url: 'https://example.test/chat',
        statusCode: 0,
        statusText: '',
        responseBody: null,
      );

      expect(error.type, DioExceptionType.connectionError);
      expect(error.response, isNull);
    });
  });
}
