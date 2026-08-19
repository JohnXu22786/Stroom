// Widget tests for temporary-conversation UI on the conversations page:
//   - countdown capsule + checked-bubble leading icon for temporary conversations
//   - three-dot menu toggle enabling temporary mode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

Conversation _conv(String id, {bool isTemporary = false}) {
  return Conversation(
    id: id,
    title: '对话$id',
    isTemporary: isTemporary,
    temporaryExpiresAt:
        isTemporary ? DateTime.now().add(kTemporaryConversationDuration) : null,
  );
}

Widget _testApp(List<Conversation> conversations) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations;
        return notifier;
      }),
    ],
    child: const MaterialApp(home: ConversationsPage()),
  );
}

void main() {
  testWidgets(
      'temporary conversation shows countdown capsule and '
      'checked-bubble leading icon', (tester) async {
    await tester.pumpWidget(_testApp([
      _conv('temp-1', isTemporary: true),
      _conv('normal-1'),
    ]));
    await tester.pump();

    // 倒计时胶囊（HH:MM）出现在临时对话条目前。
    expect(find.text('24:00'), findsOneWidget);
    // 临时对话左侧图标变为"气泡 + 打勾"（非 drag handle）。
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsOneWidget);
    // 普通对话仍保留拖拽把手。
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);

    // 菜单开启项文案随状态变化。
    expect(find.text('对话temp-1'), findsOneWidget);
    expect(find.text('对话normal-1'), findsOneWidget);
  });

  testWidgets('three-dot menu can enable temporary mode on a conversation',
      (tester) async {
    await tester.pumpWidget(_testApp([_conv('target-1'), _conv('other-1')]));
    await tester.pump();

    // 初始无临时对话：无胶囊、无勾选气泡图标。
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsNothing);

    // 打开 target-1 的更多菜单（取第一个 more_vert）。
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('临时对话'), findsOneWidget);

    await tester.tap(find.text('临时对话'));
    // 菜单关闭动画 + 状态变更重建。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 胶囊与气泡+打勾图标出现。
    expect(find.text('24:00'), findsOneWidget);
    expect(find.byIcon(Icons.mark_chat_read_outlined), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);

    // 卸载页面以释放 notifier 的周期性临时对话计时器。
    await tester.pumpWidget(const SizedBox());
  });
}
