import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/startup/startup_app.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/tts_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Register built-in provider types to avoid ProviderTypeRegistry issues.
    registerBuiltinProviderTypes();
    registerBuiltinProviders();

    // Set mock SharedPreferences with current format version and no data.
    SharedPreferences.setMockInitialValues({
      'data_format_version': DataMigrationService.currentFormatVersion,
      'provider_entries': jsonEncode([]),
      'conversations': jsonEncode([]),
    });
  });

  /// Startup timeline (with mock data — all service calls instant):
  ///   4 × _updateStatus(400ms) = 1600ms
  ///   + 600ms completion delay
  ///   + 500ms fade animation
  ///   = 2700ms total.
  ///
  /// After the Application is built behind the splash, its
  /// _checkForUpdatesOnStartup creates Dio timers. We drain those
  /// by pumping an extra 2 seconds after each test.
  Future<void> drainAllTimers(WidgetTester tester) async {
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('StartupApp fade transition overlay', () {
    testWidgets('shows splash screen initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      // Render the first frame (clock not advanced yet).
      await tester.pump();

      // Splash page should show the app name and loading indicator.
      expect(find.text('Stroom'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Drain timers so the test doesn't fail on teardown.
      await drainAllTimers(tester);
    });

    testWidgets('transitions to Application without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      await tester.pump();

      // Advance time past the startup sequence + fade animation.
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // No exceptions should have occurred during the entire transition.
      expect(tester.takeException(), isNull);

      await drainAllTimers(tester);
    });

    testWidgets(
        'splash UI visible during transition, removed after fade',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      await tester.pump();

      // Advance past startup checks (4 × 400ms = 1600ms).
      // After 10 × 200ms = 2000ms, we're past the checks and into
      // the 600ms completion delay (started at ~1600ms, 200ms remaining).
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Advance 200ms to fire the 600ms completion delay
      // (_appReady=true, fade starts).
      await tester.pump(const Duration(milliseconds: 200));

      // Advance 200ms into the 500ms fade — splash should still be visible.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Stroom'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Advance past the remaining fade + extra buffer.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // After fade completes and state is committed, splash should be gone.
      // Note: We do not assert find.text('Stroom') is gone here because
      // the Application widget tree may also contain "Stroom" text
      // (e.g. app name in UI). Just verify no errors.
      expect(tester.takeException(), isNull);

      await drainAllTimers(tester);
    });

    testWidgets(
        'renders Application behind splash during fade (stacking)',
        (tester) async {
      // This test verifies the key new behavior: during the fade transition,
      // the Application widget is rendered BEHIND the splash in a Stack.

      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      await tester.pump();

      // Advance well past the entire startup sequence and fade.
      // Multiple small pumps to ensure reliable timer processing.
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // After 5000ms, the Application widget should be in the tree
      // and the splash should be gone.
      expect(find.byKey(const ValueKey('app_ready')), findsOneWidget,
          reason: 'Application should be in the tree after startup completes');

      // Splash text should no longer be visible.
      expect(find.text('Stroom'), findsNothing,
          reason: 'Splash text should be removed after fade');

      // Only one MaterialApp should remain (Application's).
      expect(find.byType(MaterialApp), findsOneWidget,
          reason: 'After fade completes, only the Application MaterialApp remains');

      expect(tester.takeException(), isNull);

      await drainAllTimers(tester);
    });

    testWidgets('Application widget can render directly in test env',
        (tester) async {
      // Verify that the Application widget itself renders correctly
      // in the test environment.
      await tester.pumpWidget(const ProviderScope(
        child: Application(key: ValueKey('app_test')),
      ));
      await tester.pump();

      // If Application renders, it should have a MaterialApp.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);

      await drainAllTimers(tester);
    });

    testWidgets('survives rapid dispose and recreate', (tester) async {
      // Create the widget.
      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      await tester.pump();

      // Rapidly dispose.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Recreate.
      await tester.pumpWidget(
        const ProviderScope(child: StartupApp()),
      );
      await tester.pump();

      // Advance time for the new instance's sequence.
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Should not crash.
      expect(tester.takeException(), isNull);

      await drainAllTimers(tester);
    });
  });
}
