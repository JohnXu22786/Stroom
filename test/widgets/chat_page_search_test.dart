import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper identical to the existing chat_page_test.dart pattern.
Widget createChatTestApp({String? initialSearchQuery}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: ChatPage(initialSearchQuery: initialSearchQuery),
    ),
  );
}

void main() {
  group('ChatPage search mode toggle', () {
    Future<void> pumpChatPage(WidgetTester tester,
        {String? initialSearchQuery}) async {
      await tester.pumpWidget(
          createChatTestApp(initialSearchQuery: initialSearchQuery));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }

    testWidgets('shows search icon (no separate global search icon)',
        (tester) async {
      await pumpChatPage(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.manage_search), findsNothing);
    });
  });
}
