import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  group('CatCatchPage - Multi-task & Bottom Bar', () {
    testWidgets('Four input fields render (URL + 3 duration)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      // Wait for frame
      await tester.pump();

      // URL + 3 duration fields
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('Entering duration values shows hh:mm:ss preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      // Find text fields - URL field is first, then 时/分/秒 fields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4));

      await tester.enterText(textFields.at(1), '1'); // hours
      await tester.enterText(textFields.at(2), '30'); // minutes
      await tester.enterText(textFields.at(3), '15'); // seconds

      await tester.pump();

      expect(find.text('01:30:15'), findsOneWidget);
    });

    testWidgets('Duration filter hint text is visible', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      expect(
        find.text('可选：按时长筛选视频资源。留空则展示全部资源供选择'),
        findsOneWidget,
      );
    });

    testWidgets('Empty duration fields show 00:00:00 preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Login hint text is visible', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      expect(
        find.text('使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源'),
        findsOneWidget,
      );
    });

    testWidgets('Login hint is positioned below duration filter hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      final durationHint = find.text('可选：按时长筛选视频资源。留空则展示全部资源供选择');
      final loginHint = find.text('使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源');

      expect(durationHint, findsOneWidget);
      expect(loginHint, findsOneWidget);

      final durationBox = tester.renderObject<RenderBox>(durationHint);
      final loginBox = tester.renderObject<RenderBox>(loginHint);

      final durationPos = durationBox.localToGlobal(Offset.zero);
      final loginPos = loginBox.localToGlobal(Offset.zero);

      // Login hint should be below the duration hint
      expect(loginPos.dy, greaterThan(durationPos.dy));

      // There should be a small gap between them
      expect(
        loginPos.dy - durationPos.dy - durationBox.size.height,
        greaterThan(0),
        reason: 'Login hint should be slightly separated from duration hint',
      );
    });

    testWidgets('Non-numeric input in hour field handled gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      final textFields = find.byType(TextFormField);

      await tester.enterText(textFields.at(1), 'abc');
      await tester.pump();

      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Empty duration fields do NOT show snackbar error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('请输入视频时长'), findsNothing);
    });

    // ====================================================================
    // Start button tests
    // ====================================================================

    testWidgets('Start button is present and labeled correctly in bottom bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('开始分析'), findsOneWidget);
    });

    testWidgets('Start button is disabled when no URLs entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      final button = find.widgetWithText(FilledButton, '开始分析');
      expect(button, findsOneWidget);
      // Button should be disabled with no URLs
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNull);
    });

    // ====================================================================
    // Clear button tests (Icons.clear_all in app bar)
    // ====================================================================

    testWidgets('Clear_all button NOT visible when URL input is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Clear_all should not be visible when URL field is empty
      expect(find.byIcon(Icons.clear_all), findsNothing);
    });

    testWidgets('Clear_all button visible when URL input has text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Enter text into URL field
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(urlField, 'https://example.com/video.mp4');
      await tester.pump();

      // Clear_all button should appear in app bar
      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });

    testWidgets('Clear_all button clears all 4 input fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Fill URL field
      final urlField = find.byType(TextFormField).at(0);
      await tester.enterText(urlField, 'https://example.com/video.mp4');

      // Fill time fields
      await tester.enterText(find.byType(TextFormField).at(1), '1'); // hours
      await tester.enterText(find.byType(TextFormField).at(2), '30'); // minutes
      await tester.enterText(find.byType(TextFormField).at(3), '15'); // seconds
      await tester.pump();

      // Verify all fields have text
      expect(find.text('01:30:15'), findsOneWidget);
      expect(find.byIcon(Icons.clear_all), findsOneWidget);

      // Tap clear_all button
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pump();

      // Verify URL field is cleared
      expect(find.text('https://example.com/video.mp4'), findsNothing);

      // Verify time fields are cleared - preview should reset to 00:00:00
      expect(find.text('00:00:00'), findsOneWidget);

      // Clear_all button should disappear
      expect(find.byIcon(Icons.clear_all), findsNothing);
    });

    // ====================================================================
    // Multi-task URL input tests
    // ====================================================================

    testWidgets('URL input is multi-line text area', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // The URL field should accept multi-line input (newline in text)
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/1.mp4\nhttps://example.com/2.mp4',
      );
      await tester.pump();

      // Both URLs should be recognized and counted
      expect(find.text('已输入 2 个URL'), findsOneWidget);
    });

    testWidgets('Multi-line URL input: one URL enables start button', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/video.mp4',
      );
      await tester.pump();

      // Start button should now be enabled
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets('Multi-line URL input: multiple URLs all recognized', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/video1.mp4\nhttps://example.com/video2.mp4\nhttps://example.com/video3.mp4',
      );
      await tester.pump();

      // Should show URL count in bottom bar
      expect(find.text('已输入 3 个URL'), findsOneWidget);

      // Should show list of URLs
      expect(find.text('https://example.com/video1.mp4'), findsOneWidget);
      expect(find.text('https://example.com/video2.mp4'), findsOneWidget);
      expect(find.text('https://example.com/video3.mp4'), findsOneWidget);

      // Start button should be enabled
      final button = find.widgetWithText(FilledButton, '开始分析');
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull);
    });

    testWidgets(
        'Multi-line URL input: invalid URLs are filtered and not counted', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/valid.mp4\nnot-a-url\nftp://also-valid.com/video.mp4',
      );
      await tester.pump();

      // Only valid URLs should be counted (2 valid: https and ftp)
      expect(find.text('已输入 2 个URL'), findsOneWidget);

      // Not-a-url should not appear in the list
      expect(find.text('not-a-url'), findsNothing);
    });

    testWidgets('Multi-line URL input: empty lines are ignored', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/video1.mp4\n\n\nhttps://example.com/video2.mp4',
      );
      await tester.pump();

      // Only 2 valid URLs should be counted
      expect(find.text('已输入 2 个URL'), findsOneWidget);
    });

    // ====================================================================
    // Empty state tests
    // ====================================================================

    testWidgets('Empty state is shown when no URLs entered', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      expect(find.text('请输入网页URL'), findsOneWidget);
      expect(
        find.text('支持多行粘贴，每行一个URL，同时添加多个下载任务'),
        findsOneWidget,
      );
    });

    testWidgets('Empty state disappears after entering URLs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Empty state visible initially
      expect(find.text('请输入网页URL'), findsOneWidget);

      // Enter a URL
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(urlField, 'https://example.com/video.mp4');
      await tester.pump();

      // Empty state should disappear
      expect(find.text('请输入网页URL'), findsNothing);
    });

    // ====================================================================
    // Form validation tests
    // ====================================================================

    testWidgets('Validation: empty input shows error message', (tester) async {
      // Test validator directly by calling it on the TextFormField
      // The start button is disabled when no URLs are entered,
      // so form validation only triggers via explicit validate() call.
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Find the URL TextFormField and get its validator
      final urlField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      final validator = urlField.validator;
      expect(validator, isNotNull);

      // Test empty input
      final emptyResult = validator!('');
      expect(emptyResult, '请输入至少一个URL');

      // Test null input
      final nullResult = validator(null);
      expect(nullResult, '请输入至少一个URL');
    });

    testWidgets('Validation: only invalid URLs show error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Get the validator
      final urlField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      final validator = urlField.validator;
      expect(validator, isNotNull);

      // Test input with no valid URLs
      final result = validator!('not-a-url\nstill-not-valid');
      expect(result, '请输入有效的URL');
    });

    testWidgets('Validation: whitespace-only input shows error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Get the validator
      final urlField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      final validator = urlField.validator;
      expect(validator, isNotNull);

      // Test whitespace-only input
      final result = validator!('   \n  \n  ');
      expect(result, '请输入至少一个URL');
    });

    testWidgets('Validation: valid URLs pass validation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Get the validator
      final urlField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      final validator = urlField.validator;
      expect(validator, isNotNull);

      // Test valid URL
      final result = validator!('https://example.com/video.mp4');
      expect(result, isNull);
    });

    // ====================================================================
    // URL count disappearing after clear test
    // ====================================================================

    testWidgets('URL count text disappears after clear_all', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Enter multiple URLs
      final urlField = find.byType(TextFormField).first;
      await tester.enterText(
        urlField,
        'https://example.com/video1.mp4\nhttps://example.com/video2.mp4',
      );
      await tester.pump();

      // URL count should be visible
      expect(find.text('已输入 2 个URL'), findsOneWidget);

      // Tap clear_all button
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pump();

      // URL count text should disappear
      expect(find.text('已输入 2 个URL'), findsNothing);
    });

    // ====================================================================
    // Bottom bar folder selector tests
    // ====================================================================

    testWidgets('Bottom bar has video and audio folder selectors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Both folder selector labels should be present in bottom bar
      expect(find.text('视频保存至'), findsOneWidget);
      expect(find.text('音频保存至'), findsOneWidget);

      // Both should show root directory as default
      expect(find.text('根目录'), findsNWidgets(2));
    });
  });
}
