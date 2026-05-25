import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';

void main() {
  group('formatChatErrorMessage', () {
    test('未配置聊天供应商', () {
      final result = formatChatErrorMessage('请先配置聊天供应商');
      expect(result, startsWith('错误:'));
      expect(result, contains('API 未配置'));
    });

    test('API key 未配置', () {
      final result = formatChatErrorMessage('API key not configured');
      expect(result, startsWith('错误:'));
      expect(result, contains('API Key 未配置'));
    });

    test('无法连接到服务器', () {
      final err = '网络请求失败: 无法连接到服务器';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('无法连接到服务器'));
      expect(result, contains(err));
    });

    test('连接错误', () {
      final err = '连接错误: name or service not known';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('无法连接到服务器'));
      expect(result, contains(err));
    });

    test('SocketException', () {
      final err = 'SocketException: Failed host lookup: api.example.com';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('网络连接失败'));
      expect(result, contains(err));
    });

    test('Connection refused', () {
      final err = 'Connection refused: localhost:8080';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('网络连接失败'));
      expect(result, contains(err));
    });

    test('连接超时 timeout', () {
      final err = 'timeout: connection timed out';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('连接超时'));
      expect(result, contains(err));
    });

    test('连接超时 超时', () {
      final err = '连接超时: server not responding';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains('连接超时'));
      expect(result, contains(err));
    });

    test('HTTP 404', () {
      final err = 'API 请求失败 (HTTP 404): Not Found';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains(err));
    });

    test('HTTP 500', () {
      final err = 'API 请求失败 (HTTP 500): Internal Server Error';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains(err));
    });

    test('HTTP 401 - 认证失败', () {
      final err = 'API 请求失败 (HTTP 401): Invalid API key';
      final result = formatChatErrorMessage(err);
      expect(result, startsWith('错误:'));
      expect(result, contains(err));
    });

    test('其他未知错误原样显示', () {
      final err = 'some random unknown error happened';
      final result = formatChatErrorMessage(err);
      expect(result, '错误: $err');
    });

    test('空错误字符串', () {
      final result = formatChatErrorMessage('');
      expect(result, '错误: ');
    });

    test('Exception 对象', () {
      final result = formatChatErrorMessage(Exception('test error'));
      expect(result, contains('test error'));
    });
  });

  group('ChatComposerWidget - error related', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildApp({
      void Function(String, List<Attachment>)? onSend,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: Stack(
                children: [
                  ChatComposerWidget(
                    onSend: onSend ?? (_, __) {},
                    onStop: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders send button and text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
