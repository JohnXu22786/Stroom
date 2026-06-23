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
/// Important: PopScope.canPop only blocks SYSTEM back gestures (Android
/// hardware back button, iOS back swipe). It does NOT block programmatic
/// Navigator.pop() calls. The chat page's custom back button
/// (Icons.arrow_back) calls Navigator.pop() directly.
///
/// Therefore the FIX must guard the back button's onPressed handler
/// directly, checking isStreaming before deciding to pop. The PopScope
/// and its onPopInvokedWithResult handle system back gestures separately.
void main() {
  group('ChatPage back navigation', () {
    testWidgets('isStreaming=false: back pops page', (tester) async {
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
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(
              body: Center(child: Text('Root Page')),
            ),
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

      expect(find.byType(ChatPage), findsOneWidget);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Page should pop
      expect(find.byType(ChatPage), findsNothing);
      expect(find.text('Root Page'), findsOneWidget);
    });

    testWidgets('no old dialog without streaming', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith((ref) => 'conv-test-2'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(
              body: Center(child: Text('Root Page')),
            ),
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

      // The old stop dialog should never appear
      expect(find.text('停止生成？'), findsNothing);
      expect(find.text('停止并返回'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });
  });
}
