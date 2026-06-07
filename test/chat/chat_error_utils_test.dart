import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_error_utils.dart';

void main() {
  group('formatChatErrorMessage', () {
    test('API key not configured error', () {
      final msg = formatChatErrorMessage(Exception('API key not configured'));
      expect(msg, '错误: API Key 未配置，请检查设置');
    });

    test('聊天供应商未配置 error', () {
      final msg = formatChatErrorMessage(Exception('请先配置聊天供应商'));
      expect(msg, '错误: 聊天 API 未配置，请先前往设置页面配置');
    });

    test('无法连接到服务器 error', () {
      final msg = formatChatErrorMessage(Exception('无法连接到服务器'));
      expect(msg, contains('错误: 无法连接到服务器'));
      expect(msg, contains('无法连接到服务器'));
    });

    test('连接错误', () {
      final msg = formatChatErrorMessage(Exception('连接错误: timeout'));
      expect(msg, contains('错误: 无法连接到服务器'));
      expect(msg, contains('连接错误: timeout'));
    });

    test('连接失败 in Chinese', () {
      final msg = formatChatErrorMessage(Exception('连接失败: target refused'));
      expect(msg, contains('错误: 网络连接失败'));
      expect(msg, contains('连接失败: target refused'));
    });

    test('connection refused error', () {
      final msg = formatChatErrorMessage(Exception('Connection refused'));
      expect(msg, contains('错误: 网络连接失败'));
      expect(msg, contains('Connection refused'));
    });

    test('SocketException error', () {
      final msg = formatChatErrorMessage(Exception('SocketException: connection failed'));
      expect(msg, contains('错误: 网络连接失败'));
    });

    test('timeout error', () {
      final msg = formatChatErrorMessage(Exception('timeout'));
      expect(msg, contains('错误: 连接超时'));
    });

    test('HTTP error', () {
      final msg = formatChatErrorMessage(Exception('HTTP 500'));
      expect(msg, contains('HTTP 500'));
      expect(msg, startsWith('错误:'));
    });

    test('wrapped HTTP error with friendly prefix', () {
      final wrapped = Exception('API 请求失败 (HTTP 400): Conversation not found');
      final msg = formatChatErrorMessage(wrapped);
      expect(msg, contains('HTTP 400'));
      expect(msg, contains('API 请求失败 (HTTP 400)'));
      expect(msg, startsWith('错误:'));
    });

    test('generic fallback for unknown errors', () {
      final msg = formatChatErrorMessage(Exception('Unknown error'));
      expect(msg, '错误: Exception: Unknown error');
    });
  });
}
