import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed OCR with a result offers save-only retry', (
    tester,
  ) async {
    final notifier = BackgroundTaskNotifier();
    final task = BackgroundTask(
      id: 'save-retry',
      type: BackgroundTaskType.ocr,
      title: 'OCR保存失败',
      status: TaskStatus.failed,
      result: 'recognized text',
      error: 'OCR结果保存失败',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backgroundTasksProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(body: BackgroundTaskCard(task: task)),
        ),
      ),
    );
    await tester.tap(find.text('OCR保存失败'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('仅重试保存'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('incomplete OCR result offers explicit partial save', (
    tester,
  ) async {
    final notifier = BackgroundTaskNotifier();
    final task = BackgroundTask(
      id: 'partial-save',
      type: BackgroundTaskType.ocr,
      title: 'OCR截断结果',
      status: TaskStatus.failed,
      result: 'partial recognized text',
      resultIsComplete: false,
      error: 'OCR结果不完整',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backgroundTasksProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(body: BackgroundTaskCard(task: task)),
        ),
      ),
    );
    await tester.tap(find.text('OCR截断结果'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('保存部分结果'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
