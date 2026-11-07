import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/locale_provider.dart';
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

  group('web SSE error localization', () {
    test('connection and HTTP status wrappers localize only their framing', () {
      expect(
        sseClientWebConnectionFailureMessage(
          statusCode: 503,
          statusText: 'Unavailable',
          locale: const Locale('en', 'US'),
        ),
        'SSE connection failed (HTTP 503: Unavailable)',
      );
      expect(
        sseClientWebConnectionFailureMessage(
          statusCode: 503,
          statusText: 'Unavailable',
          locale: const Locale('zh', 'CN'),
        ),
        'SSE 连接失败（HTTP 503：Unavailable）',
      );
      expect(
        sseClientWebConnectionFailureMessage(
          statusCode: 0,
          statusText: '',
          locale: const Locale('zh', 'CN'),
        ),
        'SSE 连接失败：无法连接到服务器',
      );
      expect(
        sseClientWebHttpRequestFailureMessage(
          statusCode: 429,
          statusText: 'Too Many Requests',
          locale: const Locale('en', 'US'),
        ),
        'HTTP request failed (HTTP 429: Too Many Requests)',
      );
      expect(
        sseClientWebHttpRequestFailureMessage(
          statusCode: 429,
          statusText: 'Too Many Requests',
          locale: const Locale('zh', 'CN'),
        ),
        'HTTP 请求失败（HTTP 429：Too Many Requests）',
      );
    });

    test(
      'request, network, and cancellation wrappers use the locale override',
      () {
        expect(
          sseClientWebRequestFailureMessage(locale: const Locale('en', 'US')),
          'Request failed',
        );
        expect(
          sseClientWebRequestFailureMessage(locale: const Locale('zh', 'CN')),
          '请求失败',
        );
        expect(
          sseClientWebNetworkFailureMessage(locale: const Locale('en', 'US')),
          'Network request failed',
        );
        expect(
          sseClientWebNetworkFailureMessage(locale: const Locale('zh', 'CN')),
          '网络请求失败',
        );
        expect(
          sseClientWebCancellationMessage(locale: const Locale('en', 'US')),
          'Request cancelled',
        );
        expect(
          sseClientWebCancellationMessage(locale: const Locale('zh', 'CN')),
          '请求已取消',
        );
      },
    );

    test(
      'Dio errors retain response data and localize connection messages',
      () {
        final httpError = createSseClientWebFailure(
          url: 'https://example.test/chat',
          statusCode: 429,
          statusText: 'Too Many Requests',
          responseBody: '{"error":"rate limited"}',
          responseHeaders: const {
            'retry-after': ['12'],
          },
          locale: const Locale('zh', 'CN'),
        );
        expect(httpError.type, DioExceptionType.badResponse);
        expect(httpError.requestOptions.path, 'https://example.test/chat');
        expect(httpError.response?.statusCode, 429);
        expect(httpError.response?.statusMessage, 'Too Many Requests');
        expect(httpError.response?.headers.value('retry-after'), '12');
        expect(httpError.response?.data, '{"error":"rate limited"}');

        final connectionError = createSseClientWebFailure(
          url: 'https://example.test/chat',
          statusCode: 0,
          statusText: '',
          responseBody: null,
          locale: const Locale('zh', 'CN'),
        );
        expect(connectionError.type, DioExceptionType.connectionError);
        expect(connectionError.response, isNull);
        expect(connectionError.message, '网络请求失败：无法连接到服务器');

        expect(
          sseClientWebRequestFailureMessage(),
          appLocalizationsForLocale(null).sseRequestFailed,
        );
      },
    );
  });
}
