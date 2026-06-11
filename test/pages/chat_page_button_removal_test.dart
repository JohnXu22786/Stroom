import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope.
Widget createChatTestApp({String? activeConversationId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId ?? 'test-conv-id'),
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
  group('ChatPage - button removal', () {
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('NO history button (Icons.history) in top bar', (tester) async {
      await pumpChatPage(tester);

      // The history button should NOT exist
      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('NO new conversation button (Icons.add) in top bar', (tester) async {
      await pumpChatPage(tester);

      // The add button should NOT exist in ChatPage
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('NO stop button (Icons.stop_circle_outlined) in top bar',
        (tester) async {
      await pumpChatPage(tester);

      // The stop_circle_outlined icon should NOT exist in the top bar
      // (it's redundant with the one in the composer)
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('NO back button (Icons.arrow_back) in top bar',
        (tester) async {
      await pumpChatPage(tester);

      // The arrow_back icon should NOT exist in the top bar
      // (exit button removed as redundant)
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('search button still exists', (tester) async {
      await pumpChatPage(tester);

      // Search toggle should still be present
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('providers configure button still works', (tester) async {
      await pumpChatPage(tester);

      // The page should still render with the conversation title
      expect(find.text('新对话'), findsOneWidget);
    });

    testWidgets('model selector not shown when unconfigured', (tester) async {
      await pumpChatPage(tester);

      // Psychology icon (reasoning toggle) should not be present
      // when not configured
      expect(find.byIcon(Icons.psychology), findsNothing);
    });
  });
}
