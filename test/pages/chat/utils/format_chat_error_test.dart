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
}
