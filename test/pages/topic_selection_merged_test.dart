import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Creates a test app simulating the chat tab's nested Navigator structure,
/// starting at the (merged) TopicSelectionPage with pre-selected assistant.
Widget createMergedTopicTestApp({
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
  group('Merged TopicSelectionPage - AppBar', () {
    testWidgets('shows title and assistant emoji', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id', name: '测试助手', prompt: '你好', emoji: '🤖', description: '测试'),
        ],
        selectedAssistantId: 'test-id',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the title
      expect(find.text('选择话题'), findsOneWidget);
      // Assistant emoji appears in AppBar title AND info bar (2 total)
      expect(find.text('🤖'), findsAtLeast(1));
    });

    testWidgets('NO add (新话题) button in AppBar (bottom button still exists)', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id', name: '助手A', prompt: 'P1', emoji: '🤖', description: 'AA'),
        ],
        selectedAssistantId: 'test-id',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The add button should NOT be in the AppBar (search for AppBar's IconButton with Icons.add)
      // Icons.add should NOT appear as an AppBar action (only in bottom FilledButton)
      final appBar = find.byType(AppBar);
      final addIconsInAppBar = find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.add),
      );
      expect(addIconsInAppBar, findsNothing);
    });

    testWidgets('NO swap_horiz (切换助手) button in AppBar', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-2', name: '助手B', prompt: 'P2', emoji: '🤖', description: 'BB'),
        ],
        selectedAssistantId: 'test-id-2',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The swap button should NOT be in the AppBar
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });
  });

  group('Merged TopicSelectionPage - Features from ConversationsPage', () {
    testWidgets('shows search button in AppBar', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-3', name: '助手C', prompt: 'P3', emoji: '🤖', description: 'CC'),
        ],
        selectedAssistantId: 'test-id-3',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search button should exist
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows selection mode (checklist) button in AppBar', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-4', name: '助手D', prompt: 'P4', emoji: '🤖', description: 'DD'),
        ],
        selectedAssistantId: 'test-id-4',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Checklist button should be present (from ConversationsPage)
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('displays conversations with card-based UI', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '我的第一个对话',
        updatedAt: DateTime(2026, 6, 1, 10, 30),
        assistantId: 'test-id-5',
        messages: [
          ChatMessage(id: 'm1', role: 'user', content: 'Hello'),
          ChatMessage(id: 'm2', role: 'assistant', content: 'Hi'),
        ],
      );

      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-5', name: '助手E', prompt: 'P5', emoji: '🤖', description: 'EE'),
        ],
        selectedAssistantId: 'test-id-5',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show conversation title
      expect(find.text('我的第一个对话'), findsOneWidget);
      // Should show message count
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tapping conversation navigates to chat page', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话1',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-id-6',
      );

      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-6', name: '助手F', prompt: 'P6', emoji: '🤖', description: 'FF'),
        ],
        selectedAssistantId: 'test-id-6',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the conversation
      await tester.tap(find.text('对话1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should navigate to chat page
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });

    testWidgets('shows popup menu (more_vert) on each conversation card', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话D',
        updatedAt: DateTime(2026, 5, 1),
        assistantId: 'test-id-7',
      );

      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-7', name: '助手G', prompt: 'P7', emoji: '🤖', description: 'GG'),
        ],
        selectedAssistantId: 'test-id-7',
        conversations: [conv1],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Popup menu (more_vert) should exist (replaces the old delete_outline)
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows only ONE "新话题" button (bottom only, not in empty state)', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-8', name: '助手H', prompt: 'P8', emoji: '🤖', description: 'HH'),
        ],
        selectedAssistantId: 'test-id-8',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only 1 "新话题" button: the bottom one (empty state one was removed)
      expect(find.widgetWithText(FilledButton, '新话题'), findsOneWidget);
    });

    testWidgets('tapping bottom new topic button navigates to chat', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-9', name: '助手I', prompt: 'P9', emoji: '🤖', description: 'II'),
        ],
        selectedAssistantId: 'test-id-9',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Tap the LAST "新话题" FilledButton (the bottom one)
      final newTopicButtons = find.widgetWithText(FilledButton, '新话题');
      expect(newTopicButtons, findsAtLeast(1));
      await tester.tap(newTopicButtons.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Should navigate to chat page
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });
  });

  group('Merged TopicSelectionPage - Assistant info bar', () {
    testWidgets('shows assistant info bar with emoji, name, description', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(
            id: 'test-assistant',
            name: '智能助手',
            prompt: '帮助用户',
            emoji: '🧠',
            description: '一个智能助手',
          ),
        ],
        selectedAssistantId: 'test-assistant',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Emoji appears in AppBar title AND info bar
      expect(find.text('🧠'), findsAtLeast(1));
      // Name and description should appear in info bar
      expect(find.text('智能助手'), findsOneWidget);
      expect(find.text('一个智能助手'), findsOneWidget);
    });

    testWidgets('assistant info bar tune button opens combined edit dialog', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-10', name: '助手J', prompt: 'P10', emoji: '🤖', description: 'JJ'),
        ],
        selectedAssistantId: 'test-id-10',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tune button should exist
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Tap the tune button - should open combined edit dialog instead of popping back
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should open combined edit dialog with basics and settings
      expect(find.text('助手名称'), findsOneWidget);
      expect(find.text('温度 (Temperature)'), findsOneWidget);

      // Dialog should have save button
      expect(find.text('保存'), findsOneWidget);
    });
  });

  group('Merged TopicSelectionPage - Empty state', () {
    testWidgets('shows empty state when no conversations', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-11', name: '助手K', prompt: 'P11', emoji: '🤖', description: 'KK'),
        ],
        selectedAssistantId: 'test-id-11',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state text
      expect(find.text('暂无话题'), findsOneWidget);
      expect(find.text('创建一个新话题开始对话'), findsOneWidget);
    });
  });

  group('No assistant selected state', () {
    testWidgets('shows error state when no assistant is selected', (tester) async {
      await tester.pumpWidget(createMergedTopicTestApp(
        assistants: [
          Assistant(id: 'test-id-12', name: '助手L', prompt: 'P12', emoji: '🤖', description: 'LL'),
        ],
        selectedAssistantId: null,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error state (even with assistant in list, no selection)
      expect(find.text('未选择助手'), findsOneWidget);
      expect(find.text('返回选择助手'), findsOneWidget);
    });
  });
}
