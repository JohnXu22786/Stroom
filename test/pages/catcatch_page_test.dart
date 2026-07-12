import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/catcatch_page.dart';

void main() {
  group('CatCatchPage - Duration Filter Three Inputs', () {
    testWidgets('Three input fields render for hours, minutes, seconds', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      // Wait for frame
      await tester.pump();

      // Find the three text fields by their decoration labels
      // The hour field's InputDecoration has labelText: '时'
      // The minute field's InputDecoration has labelText: '分'
      // The second field's InputDecoration has labelText: '秒'
      expect(
        find.byType(TextFormField),
        findsNWidgets(4),
      ); // URL + 3 duration fields
    });

    testWidgets('Entering values shows hh:mm:ss preview below inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      // Wait for frame
      await tester.pump();

      // Find text fields - URL field is first, then 時/分/秒 fields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4));

      // The second TextFormField should be the hour field (index 1)
      // Third is minute (index 2), fourth is second (index 3)
      await tester.enterText(textFields.at(1), '1'); // hours
      await tester.enterText(textFields.at(2), '30'); // minutes
      await tester.enterText(textFields.at(3), '15'); // seconds

      // Pump to rebuild with the entered text
      await tester.pump();

      // Check that the preview text shows hh:mm:ss format
      // The preview should be something like 01:30:15
      expect(find.text('01:30:15'), findsOneWidget);
    });

    testWidgets('Hint text is visible below the duration inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      // The hint text about duration filtering should be visible (new optional text)
      expect(find.text('可选：按时长筛选视频资源。留空则展示全部资源供选择'), findsOneWidget);
    });

    testWidgets('Empty fields show 00:00:00 preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      // With empty fields, preview should show 00:00:00
      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Login hint text is visible below duration filter hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      // The login hint should be visible
      expect(find.text('使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源'), findsOneWidget);
    });

    testWidgets('Login hint is positioned below duration filter hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );

      await tester.pump();

      // Both hints should be on the page
      final durationHint = find.text('可选：按时长筛选视频资源。留空则展示全部资源供选择');
      final loginHint = find.text('使用右上角按钮，在应用内浏览器登录，以获得需要登录才能获得的资源');

      expect(durationHint, findsOneWidget);
      expect(loginHint, findsOneWidget);

      // Get render boxes to check positioning
      final durationBox = tester.renderObject<RenderBox>(durationHint);
      final loginBox = tester.renderObject<RenderBox>(loginHint);

      final durationPos = durationBox.localToGlobal(Offset.zero);
      final loginPos = loginBox.localToGlobal(Offset.zero);

      // Login hint should be below the duration hint
      expect(loginPos.dy, greaterThan(durationPos.dy));

      // There should be some gap between them (not directly adjacent)
      expect(
        loginPos.dy - durationPos.dy - durationBox.size.height,
        greaterThan(10.0),
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

    testWidgets('Empty duration fields (all zero) do NOT show snackbar error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Should NOT find the old duration-required snackbar anywhere
      expect(find.text('请输入视频时长'), findsNothing);
    });

    testWidgets('Start button is present and labeled correctly',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // Should have the start button with correct label
      expect(find.text('开始分析'), findsOneWidget);
    });

    // ====================================================================
    // Clear button tests
    // ====================================================================

    testWidgets('Clear button NOT visible when URL field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CatCatchPage())),
      );
      await tester.pump();

      // URL field should be empty initially
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('Clear button visible when URL field has text', (
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

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('Clear button clears all 4 input fields', (tester) async {
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
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Verify URL field is cleared
      expect(find.text('https://example.com/video.mp4'), findsNothing);

      // Verify time fields are cleared - preview should reset to 00:00:00
      expect(find.text('00:00:00'), findsOneWidget);

      // Clear button should disappear
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
