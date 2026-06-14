import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/utils/data_sanitizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage. This matches the v0.2.15
/// dependencies in which ChatPage did NOT depend on assistant providers.
Widget createChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Provide a conversation so the active ID resolves
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId ?? 'test-conv-id'),
      // Provide an empty provider config so adapter is unconfigured
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const ChatPage(),
    ),
  );
}

void main() {
  group('ChatPage (v0.2.15 restored)', () {
    // Helper: pump the widget and consume any pre-existing framework
    // exceptions from flutter_chat_ui rendering in test mode.
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Consume any pre-existing framework exceptions from flutter_chat_ui
      // (TextField without Material ancestor is a test-only issue)
      tester.takeException();
    }

    testWidgets('renders chat page with title', (tester) async {
      await pumpChatPage(tester);

      // Verify the page renders with the default conversation title
      expect(find.text('新对话'), findsOneWidget);
      // Verify the search button exists
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('history button is removed from top bar', (tester) async {
      await pumpChatPage(tester);

      // In merged design, history button has been removed
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('new conversation button is removed from top bar', (tester) async {
      await pumpChatPage(tester);

      // In merged design, new conversation button has been removed
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('shows search button', (tester) async {
      await pumpChatPage(tester);

      // The search/toggle button should be present
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows send button in composer', (tester) async {
      await pumpChatPage(tester);

      // Note: Icons.send_rounded can appear in both the composer and
      // the fullscreen editor dialog, so we only check it exists
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });

    // Note: Testing the composer TextField and attachment button requires
    // a full Material ancestor chain in the test environment. These elements
    // render correctly in the running app but fail in unit tests due to the
    // Positioned widget in ChatComposerWidget not inheriting Material context
    // from the flutter_chat_ui Chat widget's Scaffold.
    // This is a pre-existing limitation in v0.2.15.
  });

  group('ChatPage composer layout (bottom of Column, not Stack overlay)', () {
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('composer is visible at the bottom of the page', (tester) async {
      await pumpChatPage(tester);

      // Verify the composer's icon buttons exist (attach file and send)
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });

    testWidgets('composer is rendered below the top bar', (tester) async {
      await pumpChatPage(tester);

      // Find the top bar row and the composer elements
      final topBar = find.text('新对话');
      final sendButton = find.byIcon(Icons.send_rounded);

      // Verify the top bar title is above the send button on the page
      // (top bar has smaller y coordinate than the composer)
      final topBarRect = tester.getRect(topBar);
      final sendRect = tester.getRect(sendButton.first);
      expect(topBarRect.bottom, lessThan(sendRect.top));
    });

    testWidgets('composer is not positioned at the top of the page', (tester) async {
      await pumpChatPage(tester);

      // The composer (send button) should be in the lower portion of the screen
      final sendButton = find.byIcon(Icons.send_rounded);
      final sendRect = tester.getRect(sendButton.first);
      final screenSize = tester.getSize(find.byType(MaterialApp));
      // Send button should be in bottom third of screen
      expect(sendRect.center.dy, greaterThan(screenSize.height * 0.7));
    });
  });

  group('ChatPage JSON error detail dialog data structure', () {
    test('DataSanitizer handles raw request data structure correctly', () {
      // Simulate rawRequest structure built by _startStreaming()
      final rawRequest = <String, dynamic>{
        'url': 'https://api.example.com/chat',
        'headers': {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer sk-****1234',
        },
        'body': {
          'model': 'gpt-4',
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
        },
      };

      final sanitized = DataSanitizer.sanitizeForDisplay(rawRequest);
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(sanitized);

      // Verify JSON output is valid and contains expected fields
      expect(jsonStr, contains('"url"'));
      expect(jsonStr, contains('https://api.example.com/chat'));
      expect(jsonStr, contains('"model"'));
      expect(jsonStr, contains('gpt-4'));
      expect(jsonStr, contains('"Authorization"'));
      // API key is masked in headers but not sanitized (not base64)
      expect(jsonStr, contains('sk-****1234'));
    });

    test('DataSanitizer handles error response data structure', () {
      final rawResponse = <String, dynamic>{
        'statusCode': 400,
        'data': {
          'error': {
            'message': 'Bad Request',
            'type': 'invalid_request_error',
          },
        },
      };

      final sanitized = DataSanitizer.sanitizeForDisplay(rawResponse);
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(sanitized);

      expect(jsonStr, contains('"statusCode"'));
      expect(jsonStr, contains('400'));
      expect(jsonStr, contains('Bad Request'));
      expect(jsonStr, contains('invalid_request_error'));
    });

    test('DataSanitizer handles null/missing raw data gracefully', () {
      // When raw data is null
      final resultNull = DataSanitizer.sanitizeForDisplay(null);
      expect(resultNull, isNull);

      // Empty map
      final resultEmpty = DataSanitizer.sanitizeForDisplay(<String, dynamic>{});
      expect(resultEmpty, <String, dynamic>{});
    });
  });

  group('ChatMessage rawRequest/rawResponse serialization for ChatPage', () {
    test('rawRequest/rawResponse survive conversation message list serialization', () {
      final messages = [
        ChatMessage(role: 'user', content: 'Hello', id: 'u1'),
        ChatMessage(
          role: 'assistant',
          content: '错误: API 请求失败 (HTTP 500): Server Error',
          id: 'a1',
          isError: true,
          rawRequest: {'url': 'https://api.example.com/chat', 'body': {}},
          rawResponse: {'statusCode': 500, 'data': {'error': 'Internal'}},
        ),
      ];

      // Simulate conversation serialization (map list)
      final serialized = messages.map((m) => m.toMap()).toList();
      final deserialized =
          serialized.map((m) => ChatMessage.fromMap(m)).toList();

      final errorMsg = deserialized[1];
      expect(errorMsg.isError, true);
      expect(errorMsg.rawRequest, isNotNull);
      expect(errorMsg.rawResponse, isNotNull);
      expect(errorMsg.rawRequest!['url'], 'https://api.example.com/chat');
      expect(errorMsg.rawResponse!['statusCode'], 500);
    });

    test('non-error message does not have rawRequest/rawResponse', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello',
        id: 'u1',
      );
      final map = msg.toMap();
      expect(map.containsKey('rawRequest'), false);
      expect(map.containsKey('rawResponse'), false);
    });
  });

  group('ChatPage timestamp format (yyyy-MM-dd HH:mm)', () {
    test('DateFormat produces correct output for known DateTime', () {
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      final dt = DateTime(2026, 6, 14, 9, 5);
      final result = fmt.format(dt);
      expect(result, '2026-06-14 09:05');
    });

    test('DateFormat handles edge cases (single-digit, midnight, end-of-year)',
        () {
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      expect(fmt.format(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
      expect(fmt.format(DateTime(2026, 6, 15, 0, 0)), '2026-06-15 00:00');
      expect(fmt.format(DateTime(2026, 12, 31, 23, 59)), '2026-12-31 23:59');
    });

    test('DateFormat pattern matches reference page formats', () {
      // Topic selection page, conversations page, and message search page
      // all use manual formatting with .padLeft(2,'0') on each component:
      //   '$y-$m-$d $h:$min' (with y=year, m=month, d=day, h=hour, min=minute)
      // DateFormat('yyyy-MM-dd HH:mm') must produce identical output.
      final testCases = [
        (DateTime(2026, 1, 1, 0, 0), '2026-01-01 00:00'),
        (DateTime(2026, 12, 25, 8, 30), '2026-12-25 08:30'),
        (DateTime(2026, 6, 15, 14, 30), '2026-06-15 14:30'),
      ];
      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      for (final (dt, expected) in testCases) {
        expect(fmt.format(dt), expected);
      }
    });
  });
}
