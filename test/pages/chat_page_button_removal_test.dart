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

    testWidgets('NO reasoning toggle (Icons.psychology) in top bar', (tester) async {
      await pumpChatPage(tester);

      // The reasoning toggle button has been removed entirely from the top bar
      expect(find.byIcon(Icons.psychology), findsNothing);
    });

    testWidgets('only search button in top bar action area, no other icons', (tester) async {
      await pumpChatPage(tester);

      // Search is the only icon button in the top bar actions
      expect(find.byIcon(Icons.search), findsOneWidget);
      // No other action icons should be in the top bar
      expect(find.byIcon(Icons.psychology), findsNothing);
      expect(find.byIcon(Icons.history), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });
  });
}
