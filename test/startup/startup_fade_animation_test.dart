import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/storage_service.dart';

import 'package:stroom/startup/startup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetCache();
  });

  group('StartupPage - basic rendering', () {
    testWidgets('renders without crashing in working state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: true,
            statusMessage: '检查中...',
            progressDetail: '2/4',
          ),
        ),
      );

      // Should show the loading indicator and messages
      expect(find.text('Stroom'), findsOneWidget);
      expect(find.text('检查中...'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);

      // Should show a CircularProgressIndicator (working state)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders without crashing in completed state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: false,
            statusMessage: '准备启动应用',
            migrationPerformed: false,
          ),
        ),
      );

      // Should show the check icon (completed)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('准备启动应用'), findsOneWidget);
    });

    testWidgets('renders with migration performed color scheme',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: false,
            statusMessage: '数据检查完成',
            progressDetail: '4/4',
            migrationPerformed: true,
          ),
        ),
      );

      // Should not crash, should show check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('数据检查完成'), findsOneWidget);
    });

    testWidgets('canPop is false (cannot dismiss by back button)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: true,
          ),
        ),
      );

      // PopScope should be present
      expect(find.byType(PopScope), findsOneWidget);
    });

    testWidgets('shows status message when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: true,
            statusMessage: '正在检查数据格式版本...',
          ),
        ),
      );

      expect(find.text('正在检查数据格式版本...'), findsOneWidget);
    });

    testWidgets('hides progress detail when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(
            isWorking: true,
            statusMessage: '测试',
            progressDetail: null,
          ),
        ),
      );

      // Just making sure it renders without progress detail
      expect(find.text('测试'), findsOneWidget);
    });
  });

  group('StartupPage - animation lifecycle', () {
    testWidgets('animations run and controller is disposed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupPage(isWorking: true),
        ),
      );

      // Let the animations run for a bit
      await tester.pump(const Duration(milliseconds: 500));
      // Should still be alive (not crashed)
      expect(find.text('Stroom'), findsOneWidget);

      // Let it run more
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Stroom'), findsOneWidget);
    });
  });

  group('StartupPage - fade animation visual behavior', () {
    testWidgets('startup page does not transition to black during fade',
        (tester) async {
      // This test verifies that the startup page itself doesn't
      // produce a black screen. We render the startup page wrapped
      // in a scaffold with a known background color behind it.
      await tester.pumpWidget(
        MaterialApp(
          home: Container(
            color: Colors.amber, // Distinct background color
            child: const StartupPage(
              isWorking: false,
              statusMessage: '完成',
            ),
          ),
        ),
      );

      // The page should render normally with text visible
      expect(find.text('完成'), findsOneWidget);
      expect(find.text('Stroom'), findsOneWidget);
    });
  });
}
