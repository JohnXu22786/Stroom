// 对话列表顺序稳定性回归测试。
//
// 背景：Dart 的 List.sort 在列表长度超过 33 时使用 dual-pivot quicksort
// （不稳定排序）。旧代码用 `sort + 比较器对同组返回 0` 实现"置顶优先、
// 其余保持原顺序"，当对话条目较多时快排会任意重排等键元素——表现为
// 对话顺序"自动乱掉"（条目少时走稳定插入排序，故不一定复现）。
// 另一个问题：拖拽跨置顶/非置顶边界时，存储顺序会产生显示层无法
// 表达的隐藏交错，取消置顶/切换助手后乱序才会暴露。
//
// 修复后的不变量：state 永远是"置顶在前、块内保持相对顺序"（与显示
// 顺序一致）；显示层排序也必须是稳定的。
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Helper: create a ProviderContainer with a ConversationsNotifier that has
/// state pre-set (bypassing async _load from SharedPreferences).
ProviderContainer _createContainer({List<Conversation>? initialState}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = initialState ?? [];
        return notifier;
      }),
    ],
  );
}

List<Conversation> _convs(int n) => [
      for (var i = 0; i < n; i++) Conversation(id: 'c$i', title: '对话$i'),
    ];

void main() {
  // ===================================================================
  // pinnedFirstStable：显示层/存储层共用的稳定"置顶优先"排序
  // ===================================================================
  group('pinnedFirstStable', () {
    test('keeps relative order with 40+ conversations (unstable sort repro)',
        () {
      // 40 条：超过 List.sort 插入排序阈值（33），旧实现会在此打乱顺序。
      final all = _convs(40);
      // 置顶分散在列表各处（模拟用户拖拽/置顶后存储中的位置）。
      for (final i in [3, 9, 17, 28, 35]) {
        all[i].isPinned = true;
      }

      final result = pinnedFirstStable(all);

      final expected = <String>[
        for (final c in all)
          if (c.isPinned) c.id,
        for (final c in all)
          if (!c.isPinned) c.id,
      ];
      expect(result.map((c) => c.id).toList(), expected,
          reason: '置顶块与非置顶块都必须保持传入时的相对顺序，不能被任意重排');
    });

    test('keeps relative order with pinned and unpinned interleaved', () {
      final convs = [
        Conversation(id: 'n1', title: '普通1'),
        Conversation(id: 'p1', title: '置顶1', isPinned: true),
        Conversation(id: 'n2', title: '普通2'),
        Conversation(id: 'p2', title: '置顶2', isPinned: true),
        Conversation(id: 'n3', title: '普通3'),
      ];
      final result = pinnedFirstStable(convs);
      expect(result.map((c) => c.id).toList(),
          ['p1', 'p2', 'n1', 'n2', 'n3']);
    });
  });

  // ===================================================================
  // ConversationsNotifier - 存储不变量：state 始终"置顶在前、稳定"
  // ===================================================================
  group('ConversationsNotifier - pinned-first storage invariant', () {
    testWidgets(
        'togglePin keeps state pinned-first stable with 40+ conversations',
        (tester) async {
      final convs = _convs(40);
      convs[10].isPinned = true;
      final container = _createContainer(initialState: convs);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.togglePin('c20');
      await tester.pump(const Duration(milliseconds: 600));

      // 置顶块在前（保持原有相对顺序：c10 先于 c20），其余在后。
      expect(notifier.state.map((c) => c.id).toList(), [
        'c10',
        'c20',
        for (var i = 0; i < 40; i++)
          if (i != 10 && i != 20) 'c$i',
      ]);
    });

    testWidgets('unpinning keeps the conversation at its displayed position',
        (tester) async {
      final container = _createContainer(initialState: [
        Conversation(id: 'p1', title: '置顶', isPinned: true),
        Conversation(id: 'n1', title: '普通1'),
        Conversation(id: 'n2', title: '普通2'),
      ]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.togglePin('p1');
      await tester.pump(const Duration(milliseconds: 600));

      // 取消置顶后 p1 留在原显示位置（顶部），与旧行为一致。
      expect(notifier.state.map((c) => c.id).toList(), ['p1', 'n1', 'n2']);
    });

    testWidgets(
        'reorderConversation within the pinned block moves exactly the '
        'dragged conversation', (tester) async {
      final container = _createContainer(initialState: [
        Conversation(id: 'p1', title: '置顶1', isPinned: true),
        Conversation(id: 'p2', title: '置顶2', isPinned: true),
        Conversation(id: 'p3', title: '置顶3', isPinned: true),
        Conversation(id: 'n1', title: '普通1'),
      ]);
      final notifier = container.read(conversationsProvider.notifier);

      // onReorderItem 语义：移除后的插入索引。
      notifier.reorderConversation(0, 2);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifier.state.map((c) => c.id).toList(),
          ['p2', 'p3', 'p1', 'n1']);
    });

    testWidgets(
        'reorderConversation across the pinned boundary snaps back to the '
        'boundary instead of scrambling storage order', (tester) async {
      final container = _createContainer(initialState: [
        Conversation(id: 'p1', title: '置顶1', isPinned: true),
        Conversation(id: 'p2', title: '置顶2', isPinned: true),
        Conversation(id: 'n1', title: '普通1'),
        Conversation(id: 'n2', title: '普通2'),
      ]);
      final notifier = container.read(conversationsProvider.notifier);

      // 把置顶的 p1 拖到非置顶区末尾：跨组拖拽应吸附回置顶块底部，
      // 存储保持"置顶在前"，不得产生 p1 混入非置顶区的隐藏顺序。
      notifier.reorderConversation(0, 3);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifier.state.map((c) => c.id).toList(),
          ['p2', 'p1', 'n1', 'n2']);
    });

    testWidgets(
        'reorderConversation of an unpinned conversation into the pinned '
        'block snaps to the top of the unpinned block', (tester) async {
      final container = _createContainer(initialState: [
        Conversation(id: 'p1', title: '置顶1', isPinned: true),
        Conversation(id: 'n1', title: '普通1'),
        Conversation(id: 'n2', title: '普通2'),
        Conversation(id: 'n3', title: '普通3'),
      ]);
      final notifier = container.read(conversationsProvider.notifier);

      // 把 n3 拖到置顶区（移除后索引 1，位于 p1 与 n1 之间）。
      notifier.reorderConversation(3, 1);
      await tester.pump(const Duration(milliseconds: 600));

      // 非置顶对话不能进入置顶区：吸附到非置顶块顶部。
      expect(notifier.state.map((c) => c.id).toList(),
          ['p1', 'n3', 'n1', 'n2']);
    });

    testWidgets('createConversation keeps state pinned-first', (tester) async {
      final container = _createContainer(initialState: [
        Conversation(id: 'p1', title: '置顶', isPinned: true),
        Conversation(id: 'n1', title: '普通1'),
      ]);
      final notifier = container.read(conversationsProvider.notifier);

      final newId = notifier.createConversation();
      await tester.pump(const Duration(milliseconds: 600));

      // 新对话（未置顶）应显示在非置顶块顶部；存储不产生交错。
      expect(notifier.state.map((c) => c.id).toList(), ['p1', newId, 'n1']);
      expect(notifier.state[1].isPinned, isFalse);
    });
  });

  // ===================================================================
  // ConversationsNotifier - 加载旧数据（置顶与非置顶交错）时归一化
  // ===================================================================
  group('ConversationsNotifier - load normalizes legacy interleaved order',
      () {
    testWidgets('legacy interleaved storage is normalized on load',
        (tester) async {
      final convs = [
        Conversation(id: 'c0', title: '普通0'),
        Conversation(id: 'p1', title: '置顶1', isPinned: true),
        Conversation(id: 'c1', title: '普通1'),
        Conversation(id: 'c2', title: '普通2'),
        Conversation(id: 'p2', title: '置顶2', isPinned: true),
        Conversation(id: 'c3', title: '普通3'),
      ];
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode(convs.map((c) => c.toMap()).toList()),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      // 等待异步 _load 完成。
      for (var i = 0; i < 100 && notifier.state.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(notifier.state.map((c) => c.id).toList(),
          ['p1', 'p2', 'c0', 'c1', 'c2', 'c3']);
    });

    testWidgets(
        'in-memory conversation created during the load window survives the '
        'merge at the top of the unpinned block', (tester) async {
      final diskConvs = [
        Conversation(id: 'n1', title: '普通1'),
        Conversation(id: 'p1', title: '置顶', isPinned: true),
        Conversation(id: 'n2', title: '普通2'),
      ];
      SharedPreferences.setMockInitialValues({
        'conversations':
            jsonEncode(diskConvs.map((c) => c.toMap()).toList()),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);

      // 在 _load 完成前同步创建新对话（await SharedPreferences
      // 尚未恢复，createConversation 先改内存态）。
      final newId = notifier.createConversation();

      // 让 _load 完成并合并。
      for (var i = 0; i < 100 && notifier.state.length < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // 无论竞态先后（_load 先完成或 createConversation 先执行），
      // 最终顺序一致：置顶块 + 新对话在非置顶块顶部。
      expect(notifier.state.map((c) => c.id).toList(), ['p1', newId, 'n1', 'n2']);
    });
  });
}
