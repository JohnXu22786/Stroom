import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/utils/format_chat_error.dart';

void main() {
  group('formatChatErrorMessage', () {
    test('returns "未配置聊天供应商" message for adapter not configured', () {
      final result = formatChatErrorMessage(Exception('请先配置聊天供应商'));
      expect(result, contains('错误:'));
      expect(result, contains('聊天 API 未配置'));
    });

    test('returns "API key not configured" message', () {
      final result =
          formatChatErrorMessage(Exception('API key not configured'));
      expect(result, contains('错误:'));
      expect(result, contains('API Key 未配置'));
    });

    test('returns network error message for SocketException', () {
      final result = formatChatErrorMessage(
          Exception('SocketException: Connection refused'));
      expect(result, contains('错误:'));
      expect(result, contains('网络连接失败'));
    });

    test('returns timeout message for timeout errors', () {
      final result = formatChatErrorMessage(Exception('timeout'));
      expect(result, contains('错误:'));
      expect(result, contains('连接超时'));
    });

    test('returns raw HTTP error message', () {
      final result =
          formatChatErrorMessage(Exception('HTTP 401: Unauthorized'));
      expect(result, contains('错误:'));
      expect(result, contains('HTTP 401'));
    });

    test('returns generic error for unknown errors', () {
      final result = formatChatErrorMessage(Exception('Some unknown error'));
      expect(result, '错误: Exception: Some unknown error');
    });

    test('handles string error input', () {
      final result = formatChatErrorMessage('直接错误字符串');
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
