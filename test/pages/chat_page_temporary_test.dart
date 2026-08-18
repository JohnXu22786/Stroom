// Widget tests for the temporary-conversation toggle on the chat page top bar:
//   - icon pair swap (outline bubble ↔ bubble + check) and countdown capsule
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Pumps a ChatPage with a single seeded conversation, mirroring
/// createChatTestApp (test/pages/chat_page_test.dart) but with a resolvable
/// conversation so the top bar shows an enabled temp toggle.
Widget _appFor({
  required String activeId,
  required String convTitle,
  String? convId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [
          Conversation(id: convId ?? activeId, title: convTitle),
        ];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => activeId),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

void main() {
  testWidgets(
      'top bar toggles temporary mode on the current conversation '
      'and shows the countdown capsule', (tester) async {
    await tester.pumpWidget(_appFor(activeId: 'c-main', convTitle: '主对话'));
    await tester.pumpAndSettle();

    // 关闭态：空心气泡图标、无打勾、无倒计时胶囊。
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsNothing);
    expect(find.text('24:00'), findsNothing);

    // 点击按钮开启。
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 开启态：气泡 + 打勾图标、标题前出现倒计时胶囊。
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.text('24:00'), findsOneWidget);

    // 再点一次关闭。
    await tester.tap(find.byIcon(Icons.mark_chat_read_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsNothing);
    expect(find.text('24:00'), findsNothing);

    // 卸载页面释放 notifier 的周期性临时对话计时器。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('top-bar temp toggle is disabled without an active conversation',
      (tester) async {
    // activeId 指向列表中不存在的对话 → currentConversation 为 null。
    await tester.pumpWidget(_appFor(
      activeId: 'missing',
      convTitle: '主对话',
      convId: 'other',
    ));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chat_bubble_outline),
    );
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsNothing);
    expect(find.text('24:00'), findsNothing);
  });
}
