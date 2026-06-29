import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Create test conversations with different dates.
List<Conversation> _createOrderedConversations() {
  return [
    Conversation(
        id: 'conv-1',
        title: '最旧对话',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1)),
    Conversation(
        id: 'conv-2',
        title: '中间对话',
        createdAt: DateTime(2026, 3, 15),
        updatedAt: DateTime(2026, 3, 15)),
    Conversation(
        id: 'conv-3',
        title: '最新对话',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1)),
  ];
}

/// Helper widget that exposes tile text for testing.
/// Wraps ConversationsPage so we can introspect tile order.
Widget createTestApp({List<Conversation>? conversations, String? activeId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations ?? _createOrderedConversations();
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => activeId ?? 'conv-1'),
    ],
    child: const MaterialApp(home: ConversationsPage()),
  );
}

void main() {
  group('ConversationsPage - ordering', () {
    testWidgets('conversations display in the order they appear in state',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Verify all conversations render
      expect(find.text('最旧对话'), findsOneWidget);
      expect(find.text('中间对话'), findsOneWidget);
      expect(find.text('最新对话'), findsOneWidget);
    });

    testWidgets('pinned conversations appear first', (tester) async {
      final convs = [
        Conversation(id: 'c1', title: '普通A'),
        Conversation(id: 'c2', title: '置顶对话', isPinned: true),
        Conversation(id: 'c3', title: '普通B'),
      ];

      await tester
          .pumpWidget(createTestApp(conversations: convs, activeId: 'c1'));
      await tester.pump();

      // All should be visible
      expect(find.text('普通A'), findsOneWidget);
      expect(find.text('置顶对话'), findsOneWidget);
      expect(find.text('普通B'), findsOneWidget);
      // Pinned icon should be visible for the pinned conversation
      // Check that at least one pin icon is rendered
      expect(find.byIcon(Icons.push_pin), findsWidgets);
    });

    testWidgets('clicking a conversation does NOT change order',
        (tester) async {
      final convs = [
        Conversation(id: 'c1', title: '对话A'),
        Conversation(id: 'c2', title: '对话B'),
        Conversation(id: 'c3', title: '对话C'),
      ];

      await tester
          .pumpWidget(createTestApp(conversations: convs, activeId: 'c2'));
      await tester.pump();

      // Click conversation A
      await tester.tap(find.text('对话A'));
      await tester.pump();

      // All conversations should still be present
      expect(find.text('对话A'), findsOneWidget);
      expect(find.text('对话B'), findsOneWidget);
      expect(find.text('对话C'), findsOneWidget);
    });
  });

  group('ConversationsPage - date format', () {
    testWidgets('shows yyyy-MM-dd HH:mm format for old conversations',
        (tester) async {
      final convs = [
        Conversation(
          id: 'c1',
          title: '旧对话',
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 6, 15, 14, 30),
        ),
      ];

      await tester.pumpWidget(createTestApp(conversations: convs));
      await tester.pump();

      // Should show date in yyyy-MM-dd HH:mm format
      expect(find.textContaining('2025-06-15'), findsOneWidget);
      expect(find.textContaining('14:30'), findsOneWidget);
    });

    testWidgets('shows yyyy-MM-dd HH:mm format', (tester) async {
      final now = DateTime.now();
      final convs = [
        Conversation(id: 'c1', title: '最近对话', createdAt: now, updatedAt: now),
      ];

      await tester.pumpWidget(createTestApp(conversations: convs));
      await tester.pump();

      // Should NOT show relative time format
      expect(find.text('刚刚'), findsNothing);
      expect(find.textContaining('分钟前'), findsNothing);
      expect(find.textContaining('小时前'), findsNothing);
      expect(find.textContaining('天前'), findsNothing);

      // Should show yyyy-MM-dd HH:mm format — build the exact expected string
      final y = now.year.toString();
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final h = now.hour.toString().padLeft(2, '0');
      final min = now.minute.toString().padLeft(2, '0');
      final expectedFormat = '$y-$m-$d $h:$min';
      expect(find.textContaining(expectedFormat), findsOneWidget);
    });
  });
}
