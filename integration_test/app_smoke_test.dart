import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/startup/startup_app.dart';
import 'package:stroom/utils/text_manifest.dart';

/// End-to-end smoke tests for the Stroom app entry point.
///
/// These tests run under `flutter test integration_test/` (i.e. inside
/// `xvfb-run` on the nightly CI runner) and intentionally avoid any
/// external network calls so they remain hermetic.
///
/// Coverage:
///   1. `app launches and shows startup or home page`
///      Pumps [StartupApp] (the real app entry widget) and verifies that
///      the splash text or the home welcome text appears within a few
///      frames.
///
///   2. `app can navigate from home to settings`
///      Pumps [Application] directly, verifies the home page is shown,
///      then taps the "设置" tab in the bottom [NavigationBar] and
///      verifies that the [SettingsPage] content is rendered.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // -----------------------------------------------------------------
    // Mocks required to run the real app shell inside the test sandbox
    // -----------------------------------------------------------------
    // 1. SharedPreferences is implemented as a platform channel on
    //    Android/iOS/desktop. Substitute an in-memory implementation so
    //    the providers (theme, task list, settings, ...) do not throw
    //    `MissingPluginException` during the test.
    SharedPreferences.setMockInitialValues({});

    // 2. ManifestDatabase defaults to sqflite (native). Enable the
    //    in-memory JSON store so the test does not need the SQLite
    //    FFI bindings shipped on the runner.
    ManifestDatabase.enableTestMode();

    // 3. Text manifest caches its loaded text records in a static
    //    field; invalidate it between tests so each test starts clean.
    TextManifest.invalidateCache();
  });

  /// Wraps [child] in a [ProviderScope] with the same override the
  /// real `main()` relies on (a fresh [ThemeNotifier]). We intentionally
  /// do NOT call `registerBuiltinProviders()` etc. — they only register
  /// static metadata used by the supplier configuration UI and have no
  /// effect on the home / settings render path.
  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        themeProvider.overrideWith((ref) => ThemeNotifier()),
      ],
      child: child,
    );
  }

  testWidgets('app launches and shows startup or home page', (tester) async {
    // Use a phone-like surface so the responsive layout does not skew
    // the rendering of the startup splash or the home content.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrap(const StartupApp()));

    // The startup splash contains an infinite `repeat()` animation
    // (pulse + gradient) — `pumpAndSettle` would hang forever, so we
    // only pump a handful of frames. The splash is rendered on the
    // very first frame so a few pumps is enough to verify it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // The startup sequence runs asynchronously; depending on timing we
    // either see the splash ("Stroom" app name + tagline) or — if the
    // startup check completes very fast in the sandbox — the home
    // welcome text. Accept either outcome.
    final hasSplashText = find.text('Stroom').evaluate().isNotEmpty;
    final hasHomeText =
        find.text('欢迎使用 Stroom').evaluate().isNotEmpty;

    expect(
      hasSplashText || hasHomeText,
      isTrue,
      reason: 'Expected either the startup splash or the home page to '
          'be visible after launching the app.',
    );
    // No exception should have escaped the first frames.
    expect(tester.takeException(), isNull);
  });

  testWidgets('app can navigate from home to settings', (tester) async {
    // Force a phone-sized viewport so the bottom NavigationBar is used
    // (instead of the side NavigationRail that appears on wider
    // surfaces). Width is 390 px (iPhone-ish), well below the 600 px
    // breakpoint used by `_isMobile`.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Pump the real `Application` widget (this is what `main()` does
    // after the startup splash fades out). We skip the startup splash
    // itself because it shows a backup-storage permission dialog that
    // would block `pumpAndSettle` indefinitely in the headless sandbox.
    await tester.pumpWidget(wrap(const Application()));
    await tester.pumpAndSettle();

    // -----------------------------------------------------------------
    // Step 1: home page must be visible.
    // -----------------------------------------------------------------
    expect(
      find.text('欢迎使用 Stroom'),
      findsOneWidget,
      reason: 'Home page welcome text should be visible after launch.',
    );

    // The four bottom navigation destinations should all be present.
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // -----------------------------------------------------------------
    // Step 2: tap the "设置" destination in the bottom NavigationBar.
    // -----------------------------------------------------------------
    // Using `widgetWithText` avoids the ambiguity with the AppBar
    // title (only present on the settings page itself) and any other
    // "设置" text widgets that may appear deeper in the tree.
    final settingsTab = find.widgetWithText(NavigationDestination, '设置');
    expect(
      settingsTab,
      findsOneWidget,
      reason: 'Settings destination should be present in the '
          'bottom NavigationBar.',
    );
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    // -----------------------------------------------------------------
    // Step 3: settings page must be visible.
    // -----------------------------------------------------------------
    // `主题` is a section header on the settings page only, so it is
    // a strong, unambiguous signal that the navigation succeeded.
    expect(
      find.text('主题'),
      findsOneWidget,
      reason: 'Settings page should be visible after tapping the '
          'settings tab.',
    );

    // The AppBar title is also a stable marker of the settings page.
    expect(
      find.widgetWithText(AppBar, '设置'),
      findsOneWidget,
      reason: 'Settings page AppBar with title "设置" should be visible.',
    );
  });
}
