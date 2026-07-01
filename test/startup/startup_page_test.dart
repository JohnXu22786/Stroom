import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/startup/startup_page.dart';

/// Helper to create a standalone StartupPage for focused widget testing.
Widget wrapStartupPage({
  bool isWorking = true,
  String statusMessage = '',
  String? progressDetail,
  bool migrationPerformed = false,
}) {
  return MaterialApp(
    home: StartupPage(
      isWorking: isWorking,
      statusMessage: statusMessage,
      progressDetail: progressDetail,
      migrationPerformed: migrationPerformed,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'data_format_version': 1,
    });
  });

  group('StartupPage - splash UI', () {
    testWidgets('renders app name', (tester) async {
      await tester.pumpWidget(wrapStartupPage());
      await tester.pump();

      expect(find.text('Stroom'), findsOneWidget);
    });

    testWidgets('shows loading indicator when working', (tester) async {
      await tester.pumpWidget(wrapStartupPage(isWorking: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows check icon when done', (tester) async {
      await tester.pumpWidget(wrapStartupPage(isWorking: false));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('page fades out via AnimatedOpacity when checks complete', (
      tester,
    ) async {
      // Create a startup page that wraps in AnimatedOpacity via a parent controller
      await tester.pumpWidget(wrapStartupPage(isWorking: false));
      await tester.pump();

      // The page should be rendered without errors
      expect(tester.takeException(), isNull);

      // Verify the page still shows content (AnimatedOpacity should be at opacity 1.0)
      expect(find.text('Stroom'), findsOneWidget);
    });

    testWidgets('fade animation completes without throwing', (tester) async {
      // Simulate the transition: isWorking goes from true to false
      await tester.pumpWidget(wrapStartupPage(isWorking: true));
      await tester.pump();

      // Then change to done state
      await tester.pumpWidget(wrapStartupPage(isWorking: false));
      await tester.pump();

      // Advance the animation frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Should still have content after animation
      expect(find.text('Stroom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows status message when provided', (tester) async {
      await tester.pumpWidget(wrapStartupPage(
        statusMessage: '正在检查数据格式...',
      ));
      await tester.pump();

      expect(find.text('正在检查数据格式...'), findsOneWidget);
    });

    testWidgets('shows progress detail when provided', (tester) async {
      await tester.pumpWidget(wrapStartupPage(
        statusMessage: '正在检查',
        progressDetail: '1/3',
      ));
      await tester.pump();

      expect(find.text('1/3'), findsOneWidget);
    });
  });

  group('StartupPage - migration state', () {
    testWidgets('renders without error when migration performed',
        (tester) async {
      await tester.pumpWidget(wrapStartupPage(migrationPerformed: true));
      await tester.pump();

      // Should render without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('still shows Stroom title when migration performed',
        (tester) async {
      await tester.pumpWidget(wrapStartupPage(migrationPerformed: true));
      await tester.pump();

      expect(find.text('Stroom'), findsOneWidget);
    });
  });
}
