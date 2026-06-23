import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for ChatPage back navigation with streaming.
///
/// After the fix (allow navigation back during API streaming):
/// - PopScope.canPop is always `true` — system back is never blocked
/// - The custom back button no longer checks isStreaming — always pops
/// - The page stays alive in background: streaming continues after pop,
///   providers persist, and messages are saved when streaming completes
void main() {
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
            if (isStreaming) isStreamingProvider.overrideWith((ref) => true),
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

    // ── Core fix: system back respects PopScope with canPop=true ──
    testWidgets('isStreaming=true: PopScope is configured with canPop=true',
        (tester) async {
      await pushChatPage(tester, isStreaming: true);

      expect(find.byType(ChatPage), findsOneWidget);

      // Verify PopScope exists in the ChatPage widget tree.
      // With canPop: true, the system back (Android hardware button / iOS
      // swipe) is always allowed. The back button test above already proves
      // that programmatic Navigator.pop() works during streaming, and the
      // PopScope configuration allows system back as well.
      final popScope = find.byType(PopScope);
      expect(popScope, findsOneWidget);

      // Read the canPop property: we expect it to be true (the fix).
      // In test, PopScope.canPop starts as the passed value (true) and is
      // not overridden by any streaming check since we removed !isStreaming.
      final popScopeWidget = tester.widget<PopScope>(popScope);
      // For PopScope, canPop is a constructor parameter — we verify it's
      // set to true, meaning system back is never blocked.
      expect(popScopeWidget.canPop, isTrue);
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

    // ── Verify streaming provider persists after navigation ──
    testWidgets('isStreaming=true: streaming state persists after pop',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            return ConversationsNotifier(ref);
          }),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
      );

      // Manually set streaming state to true
      container.read(isStreamingProvider.notifier).state = true;

      // Use a simple navigator-less test: just verify the provider state
      // is set correctly. The provider is at the ProviderContainer scope,
      // which survives widget disposal. The other tests already verify
      // that back button and PopScope work correctly during streaming.
      expect(container.read(isStreamingProvider), isTrue);

      // Verify provider state is unchanged after building and disposing
      // a ChatPage widget within this container scope.
      // This simulates: navigate away → page disposed → streaming still active.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ChatPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Unmount the widget (simulates page being popped)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('New Page')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // After ChatPage is unmounted, streamingProvider should still be true
      expect(container.read(isStreamingProvider), isTrue);

      container.dispose();
    });

    // ── No old dialog ──
    testWidgets('no old dialog appears', (tester) async {
      await pushChatPage(tester, isStreaming: false);
      // The old stop dialog should never appear
      expect(find.text('停止生成？'), findsNothing);
      expect(find.text('停止并返回'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });
  });
}
