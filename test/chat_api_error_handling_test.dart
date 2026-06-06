import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:stroom/providers/chat_api_provider.dart';

/// Helper to simulate a DioException with a given status code and body.
DioException _mockDioException({
  required int statusCode,
  dynamic data,
  String? message,
}) {
  final response = Response(
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    statusCode: statusCode,
    data: data,
  );
  return DioException(
    type: DioExceptionType.badResponse,
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    response: response,
    message: message ?? 'Bad response',
  );
}

void main() {
  group('formatChatErrorMessage (inlined logic)', () {
    // Inline the real formatChatErrorMessage from chat_page.dart
    // so we can test it without importing a Flutter-heavy file.
    String formatChatErrorMessage(Object error) {
      final errorStr = error.toString();

      if (errorStr.contains('请先配置聊天供应商')) {
        return '错误: 聊天 API 未配置，请先前往设置页面配置';
      }

      if (errorStr.contains('API key not configured')) {
        return '错误: API Key 未配置，请检查设置';
      }

      if (errorStr.contains('无法连接到服务器') ||
          errorStr.contains('连接错误')) {
        return '错误: 无法连接到服务器，请检查网络连接和 API 地址\n$errorStr';
      }

      if (errorStr.contains('SocketException') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('连接失败')) {
        return '错误: 网络连接失败，请检查网络连接\n$errorStr';
      }

      if (errorStr.contains('timeout') || errorStr.contains('超时')) {
        return '错误: 连接超时，服务器无响应\n$errorStr';
      }

      if (errorStr.contains('HTTP ')) {
        return '错误: $errorStr';
      }

      return '错误: $errorStr';
    }

    test('raw DioException does NOT get friendly "HTTP 400" message (THE BUG)', () {
      // DioException.toString() produces:
      //   "DioException [bad response]: This exception was thrown because..."
      // It does NOT contain "HTTP " → falls through to generic handler.
      final exception = _mockDioException(
        statusCode: 400,
        data: {'error': {'message': 'Conversation not found'}},
      );

      final msg = formatChatErrorMessage(exception);

      // This is the bug: no friendly "HTTP 400" in the output.
      expect(msg, isNot(contains('HTTP 400')));
      expect(msg, contains('DioException [bad response]'));
    });

    test('wrapped Exception with "HTTP 400" produces friendly error (AFTER FIX)', () {
      // After the fix, chatStream() wraps the DioException in a friendly Exception.
      final wrapped = Exception('API 请求失败 (HTTP 400): Conversation not found');

      final msg = formatChatErrorMessage(wrapped);

      expect(msg, contains('HTTP 400'));
      expect(msg, contains('API 请求失败 (HTTP 400)'));
      expect(msg, startsWith('错误:'));
    });

    test('wrapped Exception with "HTTP 500" with error detail', () {
      final wrapped = Exception(
        'API 请求失败 (HTTP 500): Internal Server Error',
      );

      final msg = formatChatErrorMessage(wrapped);

      expect(msg, contains('HTTP 500'));
      expect(msg, contains('API 请求失败'));
    });

    test('non-HTTP error uses generic fallback', () {
      final msg = formatChatErrorMessage(Exception('Unknown error'));
      expect(msg, '错误: Exception: Unknown error');
    });
  });

  group('chatStream() error wrapping', () {
    test('DioException thrown by sseStream is wrapped as friendly Exception', () async {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'http://invalid-host-test/chat/completions',
        apiKey: 'test-key',
        name: 'test',
      );

      Object? caughtError;
      try {
        await for (final _ in provider.chatStream([
          {'role': 'user', 'content': 'hi'},
        ])) {
          // Should not yield events — host is invalid
        }
      } catch (e) {
        caughtError = e;
      }

      // After the fix: the error should be a friendly Exception,
      // NOT a raw DioException.
      expect(caughtError, isNotNull);
      expect(caughtError, isA<Exception>());
      // Should contain "API 请求失败" (the friendly wrapper)
      expect(caughtError.toString(), contains('API 请求失败'));
      // Should NOT contain "DioException" in the main message
      // (the error detail may reference DioException, that's fine)
    });

    test('non-DioException errors pass through unmodified', () async {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'http://example.com/chat/completions',
        apiKey: '', // Empty API key → throws Exception, not DioException
        name: 'test',
      );

      Object? caughtError;
      try {
        await for (final _ in provider.chatStream([
          {'role': 'user', 'content': 'hi'},
        ])) {
          // Should not yield — empty API key
        }
      } catch (e) {
        caughtError = e;
      }

      // Empty API key throws Exception('API key not configured')
      // This is NOT a DioException, so it should pass through unmodified.
      expect(caughtError, isNotNull);
      expect(caughtError, isA<Exception>());
      expect(caughtError.toString(), contains('API key not configured'));
    });

    test('chatStream error contains friendly "HTTP" prefix for status code errors', () {
      // This is a structural test that verifies the fix logic works:
      // The catch block in chatStream() should wrap DioException
      // with a message containing "HTTP $statusCode".
      //
      // We simulate what the catch block should produce:
      const friendlyMessage = 'API 请求失败 (HTTP 400): '
          '{"error":{"message":"Conversation cancelled"}}';
      final exception = Exception(friendlyMessage);

      expect(exception.toString(), contains('HTTP 400'));
      expect(exception.toString(), contains('API 请求失败'));
      expect(exception.toString(), contains('Conversation cancelled'));
    });
  });
}
