import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/message_search_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper: create test conversations with messages for search testing.
List<Conversation> _createTestConversations() {
  final conv1 = Conversation(
    id: 'conv-1',
    title: 'Flutter讨论',
    messages: [
      ChatMessage(
        id: 'msg-1',
        role: 'user',
        content: 'Flutter是什么框架？',
        createdAt: DateTime(2025, 1, 1),
      ),
      ChatMessage(
        id: 'msg-2',
        role: 'assistant',
        content: 'Flutter是Google开发的跨平台UI框架',
        createdAt: DateTime(2025, 1, 1),
      ),
    ],
  );

  final conv2 = Conversation(
    id: 'conv-2',
    title: '天气咨询',
    messages: [
      ChatMessage(
        id: 'msg-3',
        role: 'user',
        content: '今天天气怎么样？',
        createdAt: DateTime(2025, 1, 2),
      ),
      ChatMessage(
        id: 'msg-4',
        role: 'assistant',
        content: '今天天气晴朗，适合外出运动。',
        createdAt: DateTime(2025, 1, 2),
      ),
    ],
  );

  final conv3 = Conversation(
    id: 'conv-3',
    title: '编程学习',
    messages: [
      ChatMessage(
        id: 'msg-5',
        role: 'user',
        content: '如何学习Flutter？',
        createdAt: DateTime(2025, 1, 3),
      ),
      ChatMessage(
        id: 'msg-6',
        role: 'assistant',
        content: '推荐从Dart语言开始学习',
        createdAt: DateTime(2025, 1, 3),
      ),
      ChatMessage(
        id: 'msg-7',
        role: 'user',
        content: 'Flutter和React Native哪个好？',
        createdAt: DateTime(2025, 1, 3),
      ),
    ],
  );

  return [conv1, conv2, conv3];
}

/// Helper: create test app wrapped in ProviderScope with seeded conversations.
Widget createMessageSearchTestApp({
  List<Conversation>? conversations,
}) {
  SharedPreferences.setMockInitialValues({});
  final convs = conversations ?? _createTestConversations();
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        // Manually set state to seeded conversations
        notifier.state = convs;
        return notifier;
      }),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const MessageSearchPage(),
    ),
  );
}

void main() {
  group('MessageSearchPage - Unit: search logic', () {
    test('searchMessageContents finds matches across conversations', () {
      final convs = _createTestConversations();
      final query = 'Flutter';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      // Flutter appears in conv1 (msg-1, msg-2) and conv3 (msg-5, msg-7)
      expect(results.length, 2);

      // Both have 2 matches; sorted by title: "Flutter讨论" < "编程学习"
      expect(results[0].conversation.id, 'conv-1');
      expect(results[1].conversation.id, 'conv-3');

      // Check matches
      expect(results[0].matches.length, 2);
      expect(results[1].matches.length, 2);
    });

    test('searchMessageContents is case-insensitive', () {
      final convs = _createTestConversations();
      final query = 'flutter';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      expect(results.length, 2);
      expect(results[0].matches.length, 2);
    });

    test('searchMessageContents returns empty for no matches', () {
      final convs = _createTestConversations();
      final query = 'nonexistent';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      expect(results, isEmpty);
    });

    test('searchMessageContents returns empty for empty query', () {
      final convs = _createTestConversations();
      final query = '';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      expect(results, isEmpty);
    });

    test('searchMessageContents finds single match', () {
      final convs = _createTestConversations();
      final query = '天气';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      expect(results.length, 1);
      expect(results[0].conversation.id, 'conv-2');
      expect(results[0].matches.length, 2); // msg-3: "天气", msg-4: "天气"
    });

    test('searchMessageContents matchStart and matchEnd are correct', () {
      final convs = _createTestConversations();
      final query = 'Flutter';

      final results = MessageSearchPage.searchMessageContents(convs, query);

      // conv1, msg-1: "Flutter是什么框架？" -> match at start=0, end=7
      final conv1Result =
          results.firstWhere((r) => r.conversation.id == 'conv-1');
      final msg1Match =
          conv1Result.matches.firstWhere((m) => m.message.id == 'msg-1');
      expect(msg1Match.matchStart, 0);
      expect(msg1Match.matchEnd, 7);
    });

    test('searchMessageContents handles multiple matches in same message', () {
      final conv = Conversation(
        id: 'conv-multi',
        title: '重复测试',
        messages: [
          ChatMessage(
            id: 'msg-multi',
            role: 'user',
            content: 'test test test',
          ),
        ],
      );

      final results = MessageSearchPage.searchMessageContents([conv], 'test');
      expect(results.length, 1);
      expect(results[0].matches.length, 3);
    });

    test('searchMessageContents orders results by match count descending', () {
      final conv1 = Conversation(
        id: 'conv-a',
        title: 'A对话',
        messages: [
          ChatMessage(id: 'a1', role: 'user', content: 'apple banana'),
          ChatMessage(id: 'a2', role: 'user', content: 'apple pie'),
        ],
      );
      final conv2 = Conversation(
        id: 'conv-b',
        title: 'B对话',
        messages: [
          ChatMessage(id: 'b1', role: 'user', content: 'apple'),
        ],
      );

      final results =
          MessageSearchPage.searchMessageContents([conv1, conv2], 'apple');
      expect(results.length, 2);
      // conv-a has 2 matches (a1, a2), conv-b has 1 match (b1)
      expect(results[0].conversation.id, 'conv-a');
      expect(results[1].conversation.id, 'conv-b');
    });

    test('SearchResultMatch has correct messageId', () {
      final convs = _createTestConversations();
      final results = MessageSearchPage.searchMessageContents(convs, '天气');

      final match = results[0].matches[0];
      expect(match.messageId, isNotEmpty);
    });
  });

  group('MessageSearchPage - Widget', () {
    testWidgets('renders search page with title and search field',
        (tester) async {
      await tester.pumpWidget(createMessageSearchTestApp());
      await tester.pump();

      // Should show search field
      expect(find.byType(TextField), findsOneWidget);
      // Should show hint text
      expect(find.text('搜索所有对话中的消息...'), findsOneWidget);
      // Should have close button
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Should show initial empty state text
      expect(find.text('输入关键词搜索所有对话中的消息'), findsOneWidget);
    });

    testWidgets('shows results when searching', (tester) async {
      await tester.pumpWidget(createMessageSearchTestApp());
      await tester.pump();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pumpAndSettle();

      // Should show conversation results
      expect(find.text('Flutter讨论'), findsOneWidget);
      expect(find.text('编程学习'), findsOneWidget);

      // Should show match count badges
      expect(find.text('2 个匹配'), findsWidgets);
    });

    testWidgets('shows no results state when no matches', (tester) async {
      await tester.pumpWidget(createMessageSearchTestApp());
      await tester.pump();

      // Enter non-matching query
      await tester.enterText(find.byType(TextField), 'zzzznotfound');
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('未找到匹配的消息'), findsOneWidget);
    });

    testWidgets('tapping search result returns data via Navigator.pop',
        (tester) async {
      // Use a navigator observer to check the result
      Map<String, dynamic>? poppedResult;

      SharedPreferences.setMockInitialValues({});
      final convs = _createTestConversations();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = convs;
              return notifier;
            }),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MessageSearchPage(),
                    ),
                  );
                  poppedResult = result;
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open search page
      await tester.tap(find.text('Open Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pumpAndSettle();

      // Tap the first result item
      await tester.tap(find.text('编程学习').first);
      await tester.pumpAndSettle();

      // Verify result was returned
      expect(poppedResult, isNotNull);
      expect(poppedResult!['query'], 'Flutter');
      expect(poppedResult!['conversationId'], 'conv-3');
    });

    testWidgets('search updates as user types', (tester) async {
      await tester.pumpWidget(createMessageSearchTestApp());
      await tester.pump();

      // Type partial query
      await tester.enterText(find.byType(TextField), 'F');
      await tester.pumpAndSettle();

      // Should show results for "F" (matches "Flutter" and "框架")
      expect(find.text('Flutter讨论'), findsOneWidget);

      // Clear and type different query
      await tester.enterText(find.byType(TextField), '天气');
      await tester.pumpAndSettle();

      // Should show weather conversation only
      expect(find.text('天气咨询'), findsOneWidget);
      expect(find.text('Flutter讨论'), findsNothing);
    });
  });

  group('Conversation search unit tests', () {
    test('SearchResult has correct conversation info', () {
      final convs = _createTestConversations();
      final results = MessageSearchPage.searchMessageContents(convs, 'Flutter');

      for (final result in results) {
        expect(result.conversation.id, isNotEmpty);
        expect(result.conversation.title, isNotEmpty);
        expect(result.matches, isNotEmpty);
      }
    });

    test('SearchResultMatch has correct match positions', () {
      final convs = _createTestConversations();
      final results = MessageSearchPage.searchMessageContents(convs, 'Flutter');

      for (final result in results) {
        for (final match in result.matches) {
          expect(match.matchStart, greaterThanOrEqualTo(0));
          expect(match.matchEnd, greaterThan(match.matchStart));
          expect(
              match.matchEnd, lessThanOrEqualTo(match.message.content.length));
        }
      }
    });

    test('getSnippet returns correct text around match', () {
      final convs = _createTestConversations();
      final results = MessageSearchPage.searchMessageContents(convs, 'Flutter');

      for (final result in results) {
        for (final match in result.matches) {
          final snippet = MessageSearchPage.getSnippet(
              match.message.content, match.matchStart, match.matchEnd);
          expect(snippet, contains('Flutter'));
          expect(snippet.length, greaterThan(0));
        }
      }
    });

    test('getSnippet truncates long text', () {
      final longText = '${'A' * 50}Flutter${'B' * 50}';
      final snippet = MessageSearchPage.getSnippet(longText, 50, 57);
      expect(snippet, contains('Flutter'));
      // Should be truncated (total context 40+40+7=87 chars max)
      expect(snippet.length, lessThanOrEqualTo(90));
    });

    test('getSnippet handles text near start', () {
      final text = 'Flutter is great';
      final snippet = MessageSearchPage.getSnippet(text, 0, 7);
      expect(snippet, 'Flutter is great');
    });

    test('getSnippet handles text near end', () {
      final text = 'I love Flutter';
      final snippet = MessageSearchPage.getSnippet(text, 7, 14);
      expect(snippet, 'I love Flutter');
    });
  });
}
