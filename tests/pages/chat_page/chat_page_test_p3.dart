part of 'chat_page_test.dart';

void chatPageGroup3() {
  // ─────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────
  // From chat_page_back_navigation_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('ChatPage back navigation', () {
    /// Helper: pump a MaterialApp with a root page and push ChatPage on top.
    /// Optionally overrides isStreamingProvider to simulate streaming state.
    Future<NavigatorState> pushChatPage(
      WidgetTester tester, {
      bool isStreaming = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-test-1'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
            if (isStreaming)
              isStreamingProvider('test-conv-id').overrideWith((ref) => true),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Center(child: Text('Root Page'))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      navKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ChatPage()),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      return navKey.currentState!;
    }

    // ── Existing test: still passes ──
    testWidgets('isStreaming=false: back pops page', (tester) async {
      await pushChatPage(tester, isStreaming: false);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Page should pop
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Root Page'), findsOneWidget);
    });

    // ── Core fix: back button works during streaming ──
    testWidgets('isStreaming=true: back button pops page (no longer blocked)', (
      tester,
    ) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back — should pop even during streaming (this is the fix)
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Page should pop back to root
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Root Page'), findsOneWidget);
    });

    // ── Verify no blocking snackbar during streaming ──
    testWidgets('isStreaming=true: no blocking snackbar shown', (tester) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back — the old code showed a snackbar, new code should not
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The old "AI正在生成回复" snackbar should NOT appear
      expect(find.text('AI正在生成回复，请等待回复完成后返回'), findsNothing);
    });
  });
}
