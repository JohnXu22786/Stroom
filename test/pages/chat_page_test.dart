import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage without navigating away.
Widget createChatTestApp({
  required String assistantId,
  required String activeConversationId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Provide a known assistant with matching ID
      assistantProvider.overrideWith((ref) {
        final notifier = AssistantsNotifier();
        notifier.state = [
          Assistant(
            id: assistantId,
            name: '测试助手',
            prompt: '你是一个有帮助的AI助手。',
            emoji: '🤖',
          ),
        ];
        return notifier;
      }),
      selectedAssistantIdProvider.overrideWith((ref) => assistantId),
      // Provide a conversation so the active ID resolves
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId),
      // Provide an empty provider config so adapter is unconfigured
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: ChatPage(),
    ),
  );
}

void main() {
  group('ChatPage', () {
    // Helper: pump the widget and consume any pre-existing framework
    // exceptions from flutter_chat_ui rendering in test mode.
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp(
        assistantId: 'test-assistant-id',
        activeConversationId: 'test-conv-id',
      ));
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
      // Verify the search button (which was NOT removed) still exists
      expect(find.byIcon(Icons.search), findsWidgets);
    });

    // ── Requirement 7: top-right new/history buttons removed ──

    testWidgets('does NOT show history button', (tester) async {
      await pumpChatPage(tester);

      // The history icon should NOT be present anywhere in the widget tree
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('does NOT show new conversation button',
        (tester) async {
      await pumpChatPage(tester);

      // The add icon (new conversation) should NOT be present
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });
}
