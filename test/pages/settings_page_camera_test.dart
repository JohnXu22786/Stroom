import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/providers/notification_provider.dart';

/// Builds the test app with all required provider overrides.
/// Uses a large screen size to avoid needing to scroll.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.load();
          return notifier;
        },
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
      notificationSettingsProvider
          .overrideWith((ref) => NotificationSettingsNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsPage(),
    ),
  );
}

void main() {
  group('SettingsPage - Camera section removed', () {
    testWidgets('does NOT show save to gallery setting', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Save to gallery should no longer be shown
      expect(find.text('保存到相册'), findsNothing);
    });

    testWidgets('does NOT show camera section header', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Camera section header should no longer be shown
      expect(find.text('相机设置'), findsNothing);
    });

    testWidgets(
        'does NOT show camera-related Switch, but shows notification Switch',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Notification toggle should be present (not camera-related)
      expect(find.byType(Switch), findsWidgets);
      // Camera section should still not be present
      expect(find.text('相机设置'), findsNothing);
    });

    testWidgets(
        'settings page renders without error and shows all remaining sections',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Page should render with all expected sections except camera
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('供应商设置'), findsOneWidget);
      expect(find.text('数据备份'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      // Camera section should not be present
      expect(find.text('相机设置'), findsNothing);
    });
  });
}
