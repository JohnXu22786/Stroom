// 对话历史页显示顺序稳定性测试。
//
// 复现：Dart 的 List.sort 对 >33 个元素使用不稳定快排，旧实现
// （`sort` + 比较器对同组返回 0）会在对话条目较多时把非置顶对话
// 任意重排，表现为"顺序自动乱掉"。本测试验证 40 条对话时显示顺序
// 与存储顺序严格一致（置顶优先、块内稳定）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Helper widget that renders ConversationsPage with a seeded provider.
Widget createTestApp({required List<Conversation> conversations}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations;
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => null),
    ],
    child: const MaterialApp(home: ConversationsPage()),
  );
}

void main() {
  group('ConversationsPage - order stability with many conversations', () {
    testWidgets(
        'displays 40 conversations in stable pinned-first order (no '
        'quicksort scrambling)', (tester) async {
      // 高视口让 40 条全部被构建，便于断言完整顺序。
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final convs = <Conversation>[
        for (var i = 0; i < 40; i++) Conversation(id: 'c$i', title: '对话$i'),
      ];
      // 置顶分散在存储各处（模拟真实使用后的位置）。
      convs[3].isPinned = true;
      convs[17].isPinned = true;
      convs[28].isPinned = true;

      await tester.pumpWidget(createTestApp(conversations: convs));
      await tester.pump();

      // 期望显示顺序：置顶块（按原顺序）+ 非置顶块（按原顺序）。
      final expected = <String>[
        for (final c in convs)
          if (c.isPinned) c.title,
        for (final c in convs)
          if (!c.isPinned) c.title,
      ];

      // 按屏幕纵坐标收集每个标题的实际显示位置。
      final positions = <double, String>{};
      for (var i = 0; i < 40; i++) {
        final finder = find.text('对话$i');
        expect(finder, findsOneWidget, reason: '对话$i 应该在列表中可见（视口高度足够）');
        positions[tester.getTopLeft(finder).dy] = '对话$i';
      }
      final visibleTitles = [
        for (final y in (positions.keys.toList()..sort())) positions[y],
      ];

      expect(visibleTitles, expected,
          reason: '显示顺序必须与存储顺序一致（置顶优先、块内稳定），'
              '不能被不稳定排序打乱');
    });
  });
}
