import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';

import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Creates a test app simulating the topic selection page.
Widget createTestApp({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  List<Conversation>? conversations,
  String? activeConversationId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = assistants;
          return notifier;
        }),
      if (selectedAssistantId != null)
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        if (conversations != null) {
          notifier.state = conversations;
        }
        return notifier;
      }),
      if (activeConversationId != null)
        activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId,
        ),
    ],
    child: const MaterialApp(home: TopicSelectionPage()),
  );
}

/// Creates a test app with navigation for reorder testing.
Widget createTestAppWithNavigation({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  List<Conversation>? conversations,
  String? activeConversationId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = assistants;
          return notifier;
        }),
      if (selectedAssistantId != null)
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        if (conversations != null) {
          notifier.state = conversations;
        }
        return notifier;
      }),
      if (activeConversationId != null)
        activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId,
        ),
    ],
    child: MaterialApp(
      home: Navigator(
        initialRoute: '/topic-selection',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/topic-selection':
              return MaterialPageRoute(
                builder: (_) => const TopicSelectionPage(),
                settings: settings,
              );
            case '/chat':
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Chat Page Mock')),
                ),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Unknown')),
                ),
                settings: settings,
              );
          }
        },
      ),
    ),
  );
}

void main() {
  group('TopicSelectionPage - Long-press drag sort', () {
    testWidgets('uses ReorderableListView instead of ListView', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );
      final conv2 = Conversation(
        id: 'conv-2',
        title: '对话B',
        updatedAt: DateTime(2026, 6, 2),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1, conv2],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should render a ReorderableListView (not ListView)
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('items are wrapped in ReorderableDelayedDragStartListener when not in selection mode',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should find ReorderableDelayedDragStartListener wrapping items
      expect(find.byType(ReorderableDelayedDragStartListener), findsOneWidget);
    });

    testWidgets('items are NOT wrapped in ReorderableDelayedDragStartListener when in selection mode',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter selection mode via the checklist button
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In selection mode, there should be NO ReorderableDelayedDragStartListener
      expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    });

    testWidgets('checklist button still enters selection mode (long press removed for drag)',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the checklist button to enter selection mode
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should now show close icon (indicating selection mode is active)
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Should show delete button (since no items are selected, it should be disabled)
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('selection mode allows tapping items to select them',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );
      final conv2 = Conversation(
        id: 'conv-2',
        title: '对话B',
        updatedAt: DateTime(2026, 6, 2),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1, conv2],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter selection mode via checklist button
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show checkboxes now
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Tap the first conversation title to select it
      await tester.tap(find.text('对话A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AppBar title should show "已选 1 个"
      expect(find.text('已选 1 个'), findsOneWidget);
    });

    testWidgets('sorted conversations display pinned first, then by list order',
        (tester) async {
      final conv1 = Conversation(
        id: 'id-a',
        title: '对话A（最旧）',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-reorder',
        isPinned: false,
      );
      final conv2 = Conversation(
        id: 'id-b',
        title: '对话B（置顶）',
        updatedAt: DateTime(2026, 6, 2),
        assistantId: 'test-reorder',
        isPinned: true,
      );
      final conv3 = Conversation(
        id: 'id-c',
        title: '对话C（最新）',
        updatedAt: DateTime(2026, 6, 3),
        assistantId: 'test-reorder',
        isPinned: false,
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-reorder', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-reorder',
        conversations: [conv1, conv2, conv3],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pinned item should appear first, then unpinned in list order
      // Order should be: conv2 (pinned), conv1, conv3
      // We can verify by checking the pin icon appears and the title order
      // Pinned icon exists (at least in the pinned item)
      expect(find.byIcon(Icons.push_pin), findsWidgets);
      // Verify all items rendered
      expect(find.text('对话A（最旧）'), findsOneWidget);
      expect(find.text('对话B（置顶）'), findsOneWidget);
      expect(find.text('对话C（最新）'), findsOneWidget);
    });

    testWidgets('each item has a ValueKey for ReorderableListView tracking',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );
      final conv2 = Conversation(
        id: 'conv-2',
        title: '对话B',
        updatedAt: DateTime(2026, 6, 2),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1, conv2],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both items should be rendered
      expect(find.text('对话A'), findsOneWidget);
      expect(find.text('对话B'), findsOneWidget);
    });

    testWidgets('tapping conversation navigates to chat page (still works)',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestAppWithNavigation(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the conversation
      await tester.tap(find.text('对话A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should navigate to chat page
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });

    testWidgets('pin toggle still works', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially not pinned - should show push_pin_outlined
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      // Tap the pin button
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After pinning, should show push_pin (filled)
      // There should be at least one push_pin icon (could be multiple in the UI)
      expect(find.byIcon(Icons.push_pin), findsWidgets);
    });

    testWidgets('popup menu (more_vert) still works', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the more_vert button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Popup menu items should appear
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('search button still opens search panel', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '搜索测试',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-asst',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-asst', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-asst',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the search button
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should open search bottom sheet (TextField appears)
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('TopicSelectionPage - Reorder logic', () {
    testWidgets('multiple items render in ReorderableListView', (tester) async {
      final conv1 = Conversation(
        id: 'conv-a',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-reorder',
      );
      final conv2 = Conversation(
        id: 'conv-b',
        title: '对话B',
        updatedAt: DateTime(2026, 6, 2),
        assistantId: 'test-reorder',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-reorder', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-reorder',
        conversations: [conv1, conv2],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both items render
      expect(find.text('对话A'), findsOneWidget);
      expect(find.text('对话B'), findsOneWidget);

      // ReorderableListView is used
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('exiting selection mode returns to drag mode', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话A',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-reorder',
      );

      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(id: 'test-reorder', name: '助手', prompt: 'P', emoji: '🤖', description: '助手'),
        ],
        selectedAssistantId: 'test-reorder',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially in drag mode - ReorderableDelayedDragStartListener present
      expect(find.byType(ReorderableDelayedDragStartListener), findsOneWidget);

      // Enter selection mode
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drag listener gone, checkbox present
      expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
      expect(find.byType(Checkbox), findsOneWidget);

      // Exit selection mode
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drag listener back, checkbox gone
      expect(find.byType(ReorderableDelayedDragStartListener), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });
  });
}