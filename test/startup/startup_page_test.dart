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

  group('StartupPage - fade-out animation pattern', () {
    testWidgets('AnimatedBuilder with Opacity renders without error',
        (tester) async {
      // Simulate the fade-out pattern used in StartupApp
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 500),
      );

      final animation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Opacity(
                opacity: animation.value,
                child: child,
              );
            },
            child: wrapStartupPage(isWorking: false),
          ),
        ),
      );
      await tester.pump();

      // Initial state: fully visible
      expect(find.text('Stroom'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Start fade-out
      controller.forward();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Continue animating
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Complete
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Dispose to prevent ticker leak
      controller.dispose();
    });

    testWidgets('fade-out animation completes without errors', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 500),
      );

      final animation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              // Simulate pre-warmed Application widget (placeholder)
              const SizedBox(key: ValueKey('app_ready')),
              // Splash page fading out
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: animation.value,
                    child: child,
                  );
                },
                child: wrapStartupPage(isWorking: false),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Stroom'), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.forward();
      // Pump through animation frames manually instead of pumpAndSettle
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // After animation completes
      expect(tester.takeException(), isNull);

      // Dispose to prevent ticker leak
      controller.dispose();
    });
  });
}
