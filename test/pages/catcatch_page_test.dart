import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  group('CatCatchPage - Multi-card & Bottom Bar', () {
    testWidgets('Empty state shown when no tasks', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Should show empty state
      expect(find.text('暂无下载任务'), findsOneWidget);
      expect(find.text('点击右上角 + 添加下载任务'), findsOneWidget);
    });

    testWidgets('Add button creates a task card with URL + duration fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Should now have: URL field + 3 duration fields = 4 TextFormFields
      expect(find.byType(TextFormField), findsNWidgets(4));

      // URL hint should be visible
      expect(find.text('请输入视频/音频网页URL'), findsOneWidget);

      // Duration labels should be visible
      expect(find.text('时'), findsOneWidget);
      expect(find.text('分'), findsOneWidget);
      expect(find.text('秒'), findsOneWidget);

      // Duration hint should be visible
      expect(
        find.text('可选：按时长筛选视频资源。留空则展示全部资源供选择'),
        findsOneWidget,
      );

      // Preview should show 00:00:00 initially
      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Task card shows remove button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Should have close button
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Remove button removes the task card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Now should have 4 TextFormFields
      expect(find.byType(TextFormField), findsNWidgets(4));

      // Tap remove button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Should return to empty state
      expect(find.text('暂无下载任务'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('Can add multiple task cards', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add 3 tasks using the keyed add button
      final addButton = find.byKey(const Key('catcatch_add_task'));
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('已添加 1 个任务'), findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('已添加 2 个任务'), findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      expect(find.text('已添加 3 个任务'), findsOneWidget);

      // Verify each card has a close button (one per card)
      expect(find.byIcon(Icons.close), findsNWidgets(3));
    });

    testWidgets('Task count shows in bottom bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add 2 tasks
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Should show task count
      expect(find.text('已添加 2 个任务'), findsOneWidget);
    });

    testWidgets('Removing a task updates the count', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add 2 tasks
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('已添加 2 个任务'), findsOneWidget);

      // Remove one task
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      // Count should update to 1
      expect(find.text('已添加 1 个任务'), findsOneWidget);
    });

    testWidgets('Removing last task shows empty state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add one task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('暂无下载任务'), findsNothing);

      // Remove it
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Empty state should be back
      expect(find.text('暂无下载任务'), findsOneWidget);
    });

    testWidgets('Entering URL and duration shows preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add one task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Find the TextFormFields: URL(0), hour(1), minute(2), second(3)
      final fields = find.byType(TextFormField);

      // Enter URL
      await tester.enterText(fields.at(0), 'https://example.com/video.mp4');

      // Enter duration: 1 hour, 30 minutes, 15 seconds
      await tester.enterText(fields.at(1), '1');
      await tester.enterText(fields.at(2), '30');
      await tester.enterText(fields.at(3), '15');
      await tester.pump();

      // Preview should update
      expect(find.text('01:30:15'), findsOneWidget);
    });

    testWidgets('Start button is disabled when no valid URLs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task but don't enter URL
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Start button should be disabled
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNull);
    });

    testWidgets('Start button is enabled when valid URL entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter a valid URL
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(urlField, 'https://example.com/video.mp4');
      await tester.pump();

      // Start button should be enabled
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets('Start button enabled when at least one card has valid URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add 2 tasks
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter valid URL only on first card
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'https://example.com/video.mp4');
      await tester.pump();

      // Start button should be enabled
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    // ====================================================================
    // Duration behavior tests
    // ====================================================================

    testWidgets('Non-numeric input in hour field shows 00:00:00', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter non-numeric in hour field (index 1 = hour in 4-field card)
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'abc');
      await tester.pump();

      // Preview should stay 00:00:00
      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Duration preview shows correct format with mixed values', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter values: 0h, 5m, 0s
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), ''); // hour - empty
      await tester.enterText(fields.at(2), '5'); // minute
      await tester.enterText(fields.at(3), ''); // second - empty
      await tester.pump();

      expect(find.text('00:05:00'), findsOneWidget);
    });

    // ====================================================================
    // Bottom bar tests
    // ====================================================================

    testWidgets('Bottom bar has video and audio folder selectors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('视频保存至'), findsOneWidget);
      expect(find.text('音频保存至'), findsOneWidget);

      // Both should show "根目录" as default
      expect(find.text('根目录'), findsNWidgets(2));
    });

    testWidgets('Bottom bar shows start button with correct label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('开始分析'), findsOneWidget);
    });

    testWidgets('Browser button is present in app bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    // ====================================================================
    // Snackbar behavior
    // ====================================================================

    testWidgets('Start button disabled when only invalid URL entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Add a task with no URL
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter invalid URL
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(urlField, 'not-a-valid-url');
      await tester.pump();

      // Start button should still be disabled (invalid URL)
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNull);
    });

    testWidgets('Empty URL field shows nothing in snackbar test', (
      tester,
    ) async {
      // Regression: old duration-required snackbar should never appear
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('请输入视频时长'), findsNothing);
    });
  });
}
