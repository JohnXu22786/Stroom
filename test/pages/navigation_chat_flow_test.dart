import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Creates a test app simulating the chat tab's nested Navigator structure.
/// This allows us to test the navigation flow:
///   AssistantSelectionPage → SelectConversationPage → ChatPage
Widget createChatFlowTestApp({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  String? activeConversationId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          for (final a in assistants) {
            notifier.createAssistant(
              name: a.name,
              prompt: a.prompt,
              emoji: a.emoji,
              description: a.description,
            );
          }
          return notifier;
        }),
      if (selectedAssistantId != null)
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      if (activeConversationId != null)
        activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId,
        ),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: Navigator(
        initialRoute: '/assistant-selection',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/assistant-selection':
              return MaterialPageRoute(
                builder: (_) => const AssistantSelectionPage(),
                settings: settings,
              );
            case '/topic-selection':
              return MaterialPageRoute(
                builder: (_) => const TopicSelectionPage(),
                settings: settings,
              );
            case '/chat':
              return MaterialPageRoute(
                builder: (_) => const ChatPage(),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const AssistantSelectionPage(),
                settings: settings,
              );
          }
        },
      ),
    ),
  );
}

void main() {
  group('Chat tab navigation flow (nested Navigator)', () {
    // =========================================================================
    // 1. Chat tab always starts at AssistantSelectionPage
    // =========================================================================
    testWidgets(
        'chat tab shows AssistantSelectionPage even when activeConversationId is set',
        (tester) async {
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(name: '测试助手', prompt: '你好', emoji: '🤖', description: '测试'),
        ],
        selectedAssistantId: null,
        activeConversationId: 'previous-conv-id',
      ));
      await tester.pumpAndSettle();

      // Should show assistant selection, not chat page
      expect(find.text('选择助手'), findsOneWidget);
      expect(find.text('测试助手'), findsOneWidget);
    });

    testWidgets(
        'chat tab shows AssistantSelectionPage with no active conversation',
        (tester) async {
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(name: '默认助手', prompt: 'P1', emoji: '🤖', description: 'D1'),
        ],
        selectedAssistantId: null,
        activeConversationId: null,
      ));
      await tester.pumpAndSettle();

      expect(find.text('选择助手'), findsOneWidget);
      expect(find.text('默认助手'), findsOneWidget);
    });

    // =========================================================================
    // 2. Selecting an assistant → SelectConversationPage
    // =========================================================================
    testWidgets('tapping assistant navigates to select conversation page',
        (tester) async {
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(
              name: '助手1', prompt: 'P1', emoji: '🤖', description: '第一个助手'),
        ],
        selectedAssistantId: null,
      ));
      await tester.pumpAndSettle();

      // Tap assistant
      await tester.tap(find.text('助手1'));
      await tester.pumpAndSettle();

      // Should navigate to select conversation page (new title: 选择对话)
      expect(find.text('选择对话'), findsOneWidget);
      // Assistant selection page should not be showing (pushed off)
      expect(find.text('选择助手'), findsNothing);
    });

    // =========================================================================
    // 3. Selecting a conversation → ChatPage
    // =========================================================================
    testWidgets('creating new topic navigates to chat page', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final assistant = Assistant(
        id: 'test-assistant-id',
        name: '助手A',
        prompt: 'P1',
        emoji: '🤖',
        description: 'AA',
      );
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [assistant],
        selectedAssistantId: 'test-assistant-id',
        activeConversationId: null,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Tap the assistant to navigate to topic selection
      await tester.tap(find.text('助手A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Should be on select conversation page
      expect(find.text('选择对话'), findsOneWidget);

      // Create new topic by tapping "新话题" button
      final newTopicButtons = find.widgetWithText(FilledButton, '新话题');
      expect(newTopicButtons, findsWidgets);
      await tester.tap(newTopicButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Should now navigate to chat page
      expect(find.text('新对话'), findsWidgets);
    });

    // =========================================================================
    // 4. Back from ChatPage → SelectConversationPage
    // =========================================================================
    testWidgets('back from chat page returns to select conversation',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(name: '助手B', prompt: 'P1', emoji: '🤖', description: 'BB'),
        ],
        selectedAssistantId: null,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Go to topic selection
      await tester.tap(find.text('助手B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.text('选择对话'), findsOneWidget);

      // Create new topic to go to chat
      final newTopicBtn = find.widgetWithText(FilledButton, '新话题');
      await tester.tap(newTopicBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Verify we're on chat page
      expect(find.text('新对话'), findsWidgets);

      // Tap back button
      final backButtons = find.byTooltip('Back');
      await tester.tap(backButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should be back on select conversation page
      expect(find.text('选择对话'), findsOneWidget);
    });

    // =========================================================================
    // 5. Back from SelectConversationPage → AssistantSelectionPage
    // =========================================================================
    testWidgets('back from select conversation returns to assistant selection',
        (tester) async {
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(name: '助手C', prompt: 'P1', emoji: '🤖', description: 'CC'),
        ],
      ));
      await tester.pumpAndSettle();

      // Go to topic selection
      await tester.tap(find.text('助手C'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      // Press back using tooltip
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Should be back on assistant selection page
      expect(find.text('选择助手'), findsOneWidget);
      expect(find.text('助手C'), findsOneWidget);
    });

    // =========================================================================
    // 6. Switch assistant button → pops back to AssistantSelectionPage
    // =========================================================================
    testWidgets(
        'back navigation from select conversation returns to assistant selection',
        (tester) async {
      await tester.pumpWidget(createChatFlowTestApp(
        assistants: [
          Assistant(name: '助手D', prompt: 'P1', emoji: '🤖', description: 'DD'),
        ],
      ));
      await tester.pumpAndSettle();

      // Go to topic selection
      await tester.tap(find.text('助手D'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);

      // Use system back button to return
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should be back on assistant selection page
      expect(find.text('选择助手'), findsOneWidget);
      expect(find.text('助手D'), findsOneWidget);
    });
  });
}
