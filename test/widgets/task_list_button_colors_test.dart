import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

// =============================================================================
// Test helpers (matching patterns from existing tests)
// =============================================================================

catcatch.CatCatchTask _createCompletedCatCatchTask({
  required String id,
  String title = '已完成下载',
  String? downloadedFilePath,
}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: title,
    status: catcatch.TaskStatus.completed,
    createdAt: DateTime(2025, 1, 1),
    completedAt: DateTime(2025, 1, 1).add(const Duration(minutes: 5)),
    downloadedFilePath: downloadedFilePath ?? 'C:\\test\\video.mp4',
  );
}

SynthesisTask _createCompletedSynthesisTask({
  required String id,
  String title = '已完成合成',
  String? downloadedFilePath,
}) {
  return SynthesisTask(
    id: id,
    title: title,
    status: TaskStatus.completed,
    text: '测试文本',
    providerConfig: ProviderConfigItem(
      providerName: 'Test',
      host: 'https://test.com',
      key: 'test',
    ),
    modelConfig: ModelConfig(
      name: 'TestModel',
      modelId: 'test-model',
    ),
    createdAt: DateTime(2025, 1, 1),
    completedAt: DateTime(2025, 1, 1, 0, 3),
    statusChangedAt: DateTime(2025, 1, 1, 0, 3),
    downloadedFilePath: downloadedFilePath ?? 'C:\\test\\audio.mp3',
  );
}

BackgroundTask _createCompletedBackgroundTask({
  required String id,
  String title = '已完成后台任务',
  String? downloadedFilePath,
}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: TaskStatus.completed,
    createdAt: DateTime(2025, 1, 1),
    completedAt: DateTime(2025, 1, 1, 0, 3),
    statusChangedAt: DateTime(2025, 1, 1, 0, 3),
    downloadedFilePath: downloadedFilePath ?? 'C:\\test\\result.txt',
  );
}

/// Pump page with catcatch tasks (for verifying the standard/CatCatch card).
Future<void> pumpCatCatchPage(
  WidgetTester tester,
  List<catcatch.CatCatchTask> tasks,
) async {
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

/// Pump page with synthesis tasks.
Future<void> pumpSynthesisPage(
  WidgetTester tester,
  List<SynthesisTask> tasks,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = tasks;
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) {
          final notifier = BackgroundTaskNotifier();
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

/// Pump page with background tasks.
Future<void> pumpBackgroundPage(
  WidgetTester tester,
  List<BackgroundTask> tasks,
) async {
  final bgNotifier = BackgroundTaskNotifier();
  bgNotifier.state = tasks;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) => bgNotifier),
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

/// Expand a completed CatCatch card by tapping its header.
Future<void> expandCatCatchCard(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Expand a background task card by tapping its header.
Future<void> expandBackgroundCard(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// =============================================================================
// Tests for button color consistency
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. CatCatch task card (the standard / "获取网页资源任务卡")
  // =========================================================================
  group('CatCatch task card - button colors (standard)', () {
    testWidgets('"打开文件" button uses Colors.green', (tester) async {
      await pumpCatCatchPage(tester, [
        _createCompletedCatCatchTask(id: 'cc-1', title: '标准下载'),
      ]);

      await expandCatCatchCard(tester, '标准下载');

      // Find the "打开文件" TextButton
      final btnFinder = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(btnFinder, findsOneWidget, reason: '"打开文件"按钮应存在于已完成 CatCatch 卡片中');

      final btn = tester.widget<TextButton>(btnFinder);
      final fg = btn.style?.foregroundColor?.resolve({});
      expect(fg, equals(Colors.green), reason: '"打开文件"按钮的前景色应为 Colors.green');
    });

    testWidgets('"删除" button uses Colors.red', (tester) async {
      await pumpCatCatchPage(tester, [
        _createCompletedCatCatchTask(id: 'cc-2', title: '标准删除'),
      ]);

      await expandCatCatchCard(tester, '标准删除');

      // Find the "删除" TextButton
      final btnFinder = find.ancestor(
        of: find.text('删除'),
        matching: find.byType(TextButton),
      );
      expect(btnFinder, findsOneWidget, reason: '"删除"按钮应存在于已完成 CatCatch 卡片中');

      final btn = tester.widget<TextButton>(btnFinder);
      final fg = btn.style?.foregroundColor?.resolve({});
      expect(fg, equals(Colors.red), reason: '"删除"按钮的前景色应为 Colors.red');
    });
  });

  // =========================================================================
  // 2. Synthesis task card
  // =========================================================================
  group('Synthesis task card - button colors', () {
    testWidgets('"打开文件" button uses Colors.green', (tester) async {
      await pumpSynthesisPage(tester, [
        _createCompletedSynthesisTask(id: 'synth-1', title: '合成打开文件'),
      ]);

      // Synthesis task card shows "打开文件" directly without expand
      final btnFinder = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(btnFinder, findsOneWidget, reason: '"打开文件"按钮应存在于已完成合成卡片中');

      final btn = tester.widget<TextButton>(btnFinder);
      final fg = btn.style?.foregroundColor?.resolve({});
      expect(fg, equals(Colors.green),
          reason: '"打开文件"按钮的前景色应为 Colors.green（与 CatCatch 标准一致）');
    });

    testWidgets('delete popup menu item in completed state uses Colors.red',
        (tester) async {
      await pumpSynthesisPage(tester, [
        _createCompletedSynthesisTask(
          id: 'synth-2',
          title: '合成删除',
          downloadedFilePath: null, // no open file button, only popup
        ),
      ]);

      // Open the popup menu via the more_vert icon
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The popup should show "从列表移除" (the popup delete action)
      expect(find.text('从列表移除'), findsOneWidget, reason: 'Popup 菜单应显示"从列表移除"');
    });
  });

  // =========================================================================
  // 3. Background task card
  // =========================================================================
  group('Background task card - button colors', () {
    testWidgets('"打开文件" button uses Colors.green', (tester) async {
      await pumpBackgroundPage(tester, [
        _createCompletedBackgroundTask(
          id: 'bg-1',
          title: '后台打开文件',
        ),
      ]);

      await expandBackgroundCard(tester, '后台打开文件');

      final btnFinder = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(btnFinder, findsOneWidget, reason: '"打开文件"按钮应存在于已完成背景任务卡片中');

      final btn = tester.widget<TextButton>(btnFinder);
      final fg = btn.style?.foregroundColor?.resolve({});
      expect(fg, equals(Colors.green),
          reason: '"打开文件"按钮的前景色应为 Colors.green（与 CatCatch 标准一致）');
    });

    testWidgets('"删除" button uses Colors.red', (tester) async {
      await pumpBackgroundPage(tester, [
        _createCompletedBackgroundTask(
          id: 'bg-2',
          title: '后台删除',
        ),
      ]);

      await expandBackgroundCard(tester, '后台删除');

      // Find the "删除" TextButton
      final btnFinder = find.ancestor(
        of: find.text('删除'),
        matching: find.byType(TextButton),
      );
      expect(btnFinder, findsOneWidget, reason: '"删除"按钮应存在于背景任务卡片中');

      // Find the delete icon within the button and check its color
      final deleteIconFinder = find.descendant(
        of: btnFinder,
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(deleteIconFinder, findsOneWidget,
          reason: '"删除"按钮应包含 delete_outline 图标');

      final iconWidget = tester.widget<Icon>(deleteIconFinder);
      expect(iconWidget.color, equals(Colors.red),
          reason: '"删除"按钮的图标颜色应为 Colors.red（与 CatCatch 标准一致）');
    });
  });
}
