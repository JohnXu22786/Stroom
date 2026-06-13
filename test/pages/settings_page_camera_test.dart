import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/camera_settings_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the test app with all required provider overrides.
/// Uses a large screen size to avoid needing to scroll.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      cameraSettingsProvider.overrideWith((ref) => CameraSettingsNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.load();
          return notifier;
        },
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsPage(),
    ),
  );
}

void main() {
  group('SettingsPage - Camera section', () {
    testWidgets('shows save to gallery setting', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Save to gallery should still be shown
      expect(find.text('保存到相册'), findsOneWidget);
    });

    testWidgets('does NOT show high quality photo toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // High quality toggle should be removed
      expect(find.text('高质量照片'), findsNothing);
    });

    testWidgets('does NOT show compression quality slider', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Compression quality label should be removed
      expect(find.text('压缩质量'), findsNothing);
    });

    testWidgets('camera section header is shown', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Camera section header should still be shown
      expect(find.text('相机设置'), findsOneWidget);
    });

    testWidgets('save to gallery switch can be toggled', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find the save to gallery switch and toggle it
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);

      await tester.tap(switches);
      await tester.pumpAndSettle();

      // The switch should still be there (no crash)
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('settings page renders without error', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Page should render with all expected sections
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('相机设置'), findsOneWidget);
      expect(find.text('供应商设置'), findsOneWidget);
      expect(find.text('数据备份'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });
  });
}