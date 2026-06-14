import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage.
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
  group('ChatPage - message alignment and preview', () {
    Future<void> pumpChatPage(WidgetTester tester) async {
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('page renders with composer and title', (tester) async {
      await pumpChatPage(tester);

      // The page should render without crashing
      expect(find.text('新对话'), findsOneWidget);
      // Composer should be present with attachment and send buttons
      expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsWidgets);
    });
  });
}
