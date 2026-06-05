import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/task_provider.dart';

// =============================================================================
// Helpers
// =============================================================================
catcatch.CatCatchTask _createCompletedTask({
  required String id,
  String? downloadedFilePath,
}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '测试视频 $id',
    status: catcatch.TaskStatus.completed,
    createdAt: DateTime(2025, 1, 1),
    completedAt: DateTime(2025, 1, 1).add(const Duration(minutes: 5)),
    downloadedFilePath: downloadedFilePath,
  );
}

catcatch.CatCatchTask _createRunningTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '运行中 $id',
    status: catcatch.TaskStatus.running,
    createdAt: DateTime(2025, 1, 1),
    progress: 50,
  );
}

catcatch.CatCatchTask _createFailedTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '失败 $id',
    status: catcatch.TaskStatus.failed,
    createdAt: DateTime(2025, 1, 1),
    error: 'Download failed',
  );
}

catcatch.CatCatchTask _createPausedTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '已暂停 $id',
    status: catcatch.TaskStatus.paused,
    createdAt: DateTime(2025, 1, 1),
  );
}

/// Pump the UnifiedTaskListPage with given catcatch tasks and no synthesis tasks.
Future<void> pumpPage(WidgetTester tester, List<catcatch.CatCatchTask> tasks) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = tasks;
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        taskListLastReadProvider.overrideWith((ref) => DateTime.now()),
      ],
      child: const MaterialApp(
        home: UnifiedTaskListPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Expand a completed task card by tapping the header.
/// Completed tasks start collapsed; we tap the status label to expand.
Future<void> expandCompletedCard(WidgetTester tester) async {
  // Tap the card header (status label) to expand it
  await tester.tap(find.text('已完成 · 0%'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // wait for animation
}

// =============================================================================
// Tests
// =============================================================================
void main() {
  group('UnifiedTaskListPage - "打开文件" button', () {
    // -------------------------------------------------------------------------
    // Test 1: 已完成任务 — 展开卡片后显示"打开文件"按钮且可点击
    // -------------------------------------------------------------------------
    testWidgets('completed task shows tappable Open File button when expanded',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
          id: 'test-1',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      // 已完成卡片默认折叠 → 先展开
      await expandCompletedCard(tester);

      // 查找"打开文件"文本
      expect(find.text('打开文件'), findsOneWidget,
          reason: '展开已完成卡片后应显示"打开文件"按钮');

      // 查找 TextButton
      final textButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget,
          reason: '"打开文件"文本应该在 TextButton 内');

      // 验证按钮尺寸 > 0（修复前可能为 0）
      final size = tester.getSize(textButton);
      expect(size.width, greaterThan(0),
          reason: '按钮宽度应大于 0（当前为 ${size.width}）');
      expect(size.height, greaterThan(0),
          reason: '按钮高度应大于 0（当前为 ${size.height}）');

      // 验证 onPressed 不为 null
      final button = tester.widget<TextButton>(textButton);
      expect(button.onPressed, isNotNull,
          reason: '"打开文件"按钮的 onPressed 不应为 null');

      // 点击按钮（不应抛出异常）
      await tester.tap(textButton);
      await tester.pump();
    });

    // -------------------------------------------------------------------------
    // Test 2: 已完成任务无 downloadedFilePath → 展开后也不显示"打开文件"
    // -------------------------------------------------------------------------
    testWidgets(
        'completed task without downloadedFilePath hides Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(id: 'test-2', downloadedFilePath: null),
      ]);

      // 展开卡片
      await expandCompletedCard(tester);

      expect(find.text('打开文件'), findsNothing,
          reason: 'downloadedFilePath 为 null 时不应显示"打开文件"按钮');
    });

    // -------------------------------------------------------------------------
    // Test 3: 运行中任务（默认已展开）不显示"打开文件"按钮
    // -------------------------------------------------------------------------
    testWidgets('running task should not show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createRunningTask(id: 'test-3'),
      ]);

      // 运行中任务默认展开，直接检查
      expect(find.text('打开文件'), findsNothing,
          reason: '运行中的任务不应显示"打开文件"按钮');
    });

    // -------------------------------------------------------------------------
    // Test 4: 失败任务（需展开）不显示"打开文件"按钮
    // -------------------------------------------------------------------------
    testWidgets('failed task should not show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createFailedTask(id: 'test-4'),
      ]);

      // 失败任务默认折叠，点击状态文本展开后检查
      await tester.tap(find.text('失败 · 0%'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '失败的任务不应显示"打开文件"按钮');
    });

    // -------------------------------------------------------------------------
    // Test 5: 暂停任务（需展开）不显示"打开文件"按钮
    // -------------------------------------------------------------------------
    testWidgets('paused task should not show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createPausedTask(id: 'test-5'),
      ]);

      // 暂停任务默认折叠，点击状态文本展开后检查
      await tester.tap(find.text('已暂停 · 0%'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '暂停的任务不应显示"打开文件"按钮');
    });

    // -------------------------------------------------------------------------
    // Test 6: 空状态显示"暂无任务"
    // -------------------------------------------------------------------------
    testWidgets('empty task list shows placeholder', (tester) async {
      await pumpPage(tester, []);

      expect(find.text('暂无任务'), findsOneWidget,
          reason: '空任务列表应显示"暂无任务"占位符');
    });

    // -------------------------------------------------------------------------
    // Test 7: 多个已完成任务 — 展开后每个都有"打开文件"按钮
    // -------------------------------------------------------------------------
    testWidgets('multiple completed tasks all show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(id: 'm1', downloadedFilePath: 'C:\\a.mp4'),
        _createCompletedTask(id: 'm2', downloadedFilePath: 'C:\\b.mp4'),
        _createCompletedTask(id: 'm3', downloadedFilePath: 'C:\\c.mp4'),
      ]);

      // 分别展开每个卡片
      // 每个卡片显示"已完成 · 0%"的文本 — 有3个
      expect(find.text('已完成 · 0%'), findsNWidgets(3));

      // 逐一点击每个卡片头部的状态文本以展开
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('已完成 · 0%').at(i));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 现在所有3个卡片都已展开，应有3个"打开文件"按钮
      expect(find.text('打开文件'), findsNWidgets(3),
          reason: '3个已完成卡片展开后应显示3个"打开文件"按钮');

      // 验证每个按钮 onPressed 不为 null
      final buttons = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        final btn = buttons.at(i);
        final widget = tester.widget<TextButton>(btn);
        expect(widget.onPressed, isNotNull,
            reason: '第 $i 个按钮的 onPressed 不应为 null');
      }
    });

    // -------------------------------------------------------------------------
    // Test 8: 验证按钮有足够的 tap target 尺寸（最小触摸目标检查）
    // -------------------------------------------------------------------------
    testWidgets('Open File button has adequate tap target size',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
          id: 'test-tap',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      await expandCompletedCard(tester);

      final textButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget);

      final size = tester.getSize(textButton.first);
      // Material 默认最小触摸目标为 48x48 逻辑像素
      expect(size.width, greaterThan(0),
          reason: '按钮宽度必须 > 0（修复前可能为 0）');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '按钮高度应 >= 48（Material 最小触摸目标，修复前因 shrinkWrap 仅为 ~20）');
    });

    // -------------------------------------------------------------------------
    // Test 9: 展开卡片后切换到"下载"tab 也能看到按钮
    // -------------------------------------------------------------------------
    testWidgets('Open File button visible in Downloads tab', (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
          id: 'test-tab',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      // 先在"全部"tab 展开卡片
      await expandCompletedCard(tester);

      // 切换到"下载"tab
      await tester.tap(find.text('下载'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));  // 等 TabBarView 切换动画

      // 切换到"下载"tab 后卡片是新的 Widget 实例，需要重新展开
      await expandCompletedCard(tester);

      // "打开文件"按钮应可见
      expect(find.text('打开文件'), findsOneWidget,
          reason: '"下载"tab中应能看到"打开文件"按钮');

      final downloadTabButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );

      // 验证按钮存在并点击
      expect(downloadTabButton, findsOneWidget,
          reason: '"下载"tab中应能看到"打开文件"按钮');
      await tester.tap(downloadTabButton);
      await tester.pump();
    });
  });
}
