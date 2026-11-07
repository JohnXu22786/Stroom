import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:stroom/pages/chat/utils/format_chat_error.dart';

String formatChatErrorMessageInChinese(Object error) =>
    formatChatErrorMessage(error, locale: const Locale('zh', 'CN'));

void main() {
  group('formatChatErrorMessage', () {
    test('localizes app framing while preserving network details', () {
      const details =
          'SocketException: Connection refused https://api.example.test/v1';

      final english = formatChatErrorMessage(
        Exception(details),
        locale: const Locale('en', 'US'),
      );
      final chinese = formatChatErrorMessage(
        Exception(details),
        locale: const Locale('zh', 'CN'),
      );

      expect(english, contains('Network connection failed'));
      expect(english, contains(details));
      expect(chinese, contains('网络连接失败'));
      expect(chinese, contains(details));
      expect(formatChatErrorMessage('plain'), '错误: plain');

      const serverDetails = 'HTTP 502 https://api.example.test/v1';
      final serverError = formatChatErrorMessage(
        Exception('无法连接到服务器: $serverDetails'),
        locale: const Locale('en', 'US'),
      );
      expect(serverError, contains('Unable to connect to the server'));
      expect(serverError, isNot(contains('无法连接到服务器')));
      expect(serverError, contains('Exception:'));
      expect(serverError, contains(serverDetails));

      const providerDetails = 'provider=Demo https://api.example.test';
      final providerError = formatChatErrorMessage(
        Exception('请先配置聊天供应商: $providerDetails'),
        locale: const Locale('en', 'US'),
      );
      const apiKeyDetails = 'provider=Demo https://api.example.test';
      final apiKeyError = formatChatErrorMessage(
        Exception('API key not configured: $apiKeyDetails'),
        locale: const Locale('zh', 'CN'),
      );
      expect(providerError, isNot(contains('请先配置聊天供应商')));
      expect(providerError, contains('\nException:'));
      expect(providerError, contains(providerDetails));
      expect(apiKeyError, isNot(contains('API key not configured')));
      expect(apiKeyError, contains('\nException:'));
      expect(apiKeyError, contains(apiKeyDetails));
    });

    test('returns "未配置聊天供应商" message for adapter not configured', () {
      final result = formatChatErrorMessageInChinese(Exception('请先配置聊天供应商'));
      expect(result, contains('错误:'));
      expect(result, contains('聊天 API 未配置'));
    });

    test('returns "API key not configured" message', () {
      final result =
          formatChatErrorMessageInChinese(Exception('API key not configured'));
      expect(result, contains('错误:'));
      expect(result, contains('API Key 未配置'));
      expect(result, isNot(contains('Exception:')));
    });

    test('returns network error message for SocketException', () {
      final result = formatChatErrorMessageInChinese(
          Exception('SocketException: Connection refused'));
      expect(result, contains('错误:'));
      expect(result, contains('网络连接失败'));
    });

    test('returns timeout message for timeout errors', () {
      final result = formatChatErrorMessageInChinese(Exception('timeout'));
      expect(result, contains('错误:'));
      expect(result, contains('连接超时'));
    });

    test('returns raw HTTP error message', () {
      final result =
          formatChatErrorMessageInChinese(Exception('HTTP 401: Unauthorized'));
      expect(result, contains('错误:'));
      expect(result, contains('HTTP 401'));
    });

    test('returns generic error for unknown errors', () {
      final result =
          formatChatErrorMessageInChinese(Exception('Some unknown error'));
      expect(result, '错误: Exception: Some unknown error');
    });

    test('handles string error input', () {
      final result = formatChatErrorMessageInChinese('直接错误字符串');
      expect(result, '错误: 直接错误字符串');
    });
  });

  group('formatErrorValueForDisplay', () {
    test('pretty-prints JSON strings with indentation', () {
      final result =
          formatErrorValueForDisplay('{"error":{"message":"bad request"}}');
      expect(result, startsWith('{\n'));
      expect(result, contains('"message": "bad request"'));
    });

    test('unwraps raw-keyed streaming body and pretty-prints JSON', () {
      final result = formatErrorValueForDisplay(
          {'raw': '{"error":{"message":"stream failed"}}'});
      expect(result, startsWith('{\n'));
      expect(result, contains('"message": "stream failed"'));
      expect(result, isNot(contains('"raw"')));
    });

    test('unwraps raw-keyed body with plain text', () {
      expect(
        formatErrorValueForDisplay({'raw': 'connection reset'}),
        'connection reset',
      );
    });

    test('returns non-JSON strings as-is', () {
      expect(
          formatErrorValueForDisplay('plain error text'), 'plain error text');
    });

    test('returns invalid JSON starting with { as-is (catch fallback)', () {
      expect(formatErrorValueForDisplay('{"a":1}x'), '{"a":1}x');
    });

    test('does not unwrap raw map when it has extra keys', () {
      final result = formatErrorValueForDisplay({
        'raw': '{"error":{"message":"stream failed"}}',
        'statusCode': 400,
      });
      expect(result, startsWith('{\n'));
      expect(result, contains('"statusCode": 400'));
      expect(result, contains('"raw"'));
    });

    test('pretty-prints Maps as JSON without truncation', () {
      final longValue = '错' * 500;
      final result = formatErrorValueForDisplay({
        'error': {'message': longValue},
      });
      expect(result, startsWith('{\n'));
      expect(result, contains(longValue));
      expect(result, isNot(endsWith('...')));
    });

    test('returns long strings without truncation', () {
      final longValue = '错' * 500;
      final result = formatErrorValueForDisplay(longValue);
      expect(result, longValue);
    });

    test('pretty-prints long JSON strings without truncation', () {
      final longValue = '错' * 500;
      final result =
          formatErrorValueForDisplay('{"error":{"message":"$longValue"}}');
      expect(result, contains(longValue));
      expect(result, isNot(endsWith('...')));
    });

    test('falls back to toString for other types', () {
      expect(formatErrorValueForDisplay(42), '42');
      expect(formatErrorValueForDisplay(null), '');
    });
  });
}
