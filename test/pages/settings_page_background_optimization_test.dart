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
  group('SettingsPage - 任务 section & 后台运行优化 card', () {
    testWidgets('shows 任务 section header instead of 通知', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the new 任务 header
      expect(find.text('任务'), findsOneWidget);
      // Should NOT show the old 通知 header
      expect(find.text('通知'), findsNothing);
    });

    testWidgets('shows 任务完成通知 toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Toggle text should still exist
      expect(find.text('任务完成通知'), findsOneWidget);
      expect(find.text('任务完成或失败时发送通知'), findsOneWidget);
      // At least one Switch should be present (the notification toggle)
      expect(find.byType(Switch), findsWidgets);
      // Specifically the notification toggle subtitle text should be present
      expect(find.text('任务完成或失败时发送通知'), findsOneWidget);
    });

    testWidgets('shows 后台运行优化 card entry', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The new card should be visible
      expect(find.text('后台运行优化'), findsOneWidget);
    });

    testWidgets('tapping 后台运行优化 navigates to BackgroundOptimizationPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the 后台运行优化 card
      await tester.tap(find.text('后台运行优化'));
      await tester.pumpAndSettle();

      // Should navigate to BackgroundOptimizationPage (verify unique content)
      expect(find.text('系统环境检测'), findsOneWidget);
      expect(find.text('平台教程'), findsOneWidget);
    });

    testWidgets('settings page still renders all other sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // All original sections should still be present
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('供应商设置'), findsOneWidget);
      expect(find.text('数据备份'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });
  });
}
