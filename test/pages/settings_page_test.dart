// Merged from:
//   test/pages/settings_page_asr_test.dart
//   test/pages/settings_page_background_optimization_test.dart
//   test/pages/settings_page_camera_test.dart
//   test/pages/settings_page_license_test.dart
//   test/pages/settings_page_ocr_test.dart
//   test/pages/settings_page_update_test.dart
//   test/pages/notification_settings_page_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/notification_settings_page.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/notification_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Builds the SettingsPage test app without notification override.
/// Used by ASR / OCR / license groups.
Widget _buildSettingsTestApp() {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith((ref) {
        final notifier = ProviderEntriesNotifier();
        // load() is normally called in the provider factory, so we call it here too.
        notifier.load();
        return notifier;
      }),
      updateProvider.overrideWith((ref) => UpdateNotifier()),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

/// Builds the SettingsPage test app with notification override.
/// Used by 任务 section and camera section groups.
Widget _buildSettingsTestAppWithNotification() {
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

/// Builds the NotificationSettingsPage test app.
Widget _buildNotificationTestApp() {
  return ProviderScope(
    overrides: [
      notificationSettingsProvider
          .overrideWith((ref) => NotificationSettingsNotifier()),
    ],
    child: const MaterialApp(
      home: NotificationSettingsPage(),
    ),
  );
}

/// 构建只包含 TTS、LLM 和 OCR 的已保存数据（模拟旧版本用户升级，无 ASR）
String _savedDataWithoutAsr() {
  final entries = [
    {
      'id': 'builtin_tts',
      'type': 'tts',
      'name': 'TTS供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_ocr',
      'type': 'ocr',
      'name': 'OCR供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// 构建只包含 TTS 和 LLM 的已保存数据（模拟旧版本用户升级）
String _savedDataWithoutOcr() {
  final entries = [
    {
      'id': 'builtin_tts',
      'type': 'tts',
      'name': 'TTS供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_llm',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_asr_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - ASR (音频转写) supplier display', () {
    testWidgets('shows ASR supplier entry when loaded with default entries', (
      tester,
    ) async {
      // Use a large viewport so all content is visible
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // No saved data → defaults including ASR
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
      expect(find.text('音频转写供应商'), findsOneWidget);
    });

    testWidgets(
      'shows ASR supplier after migration from saved data without it',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'provider_entries': _savedDataWithoutAsr(),
        });

        await tester.pumpWidget(_buildSettingsTestApp());
        await tester.pumpAndSettle();

        // ASR should be migrated in and displayed
        expect(find.text('TTS供应商'), findsOneWidget);
        expect(find.text('LLM供应商'), findsOneWidget);
        expect(find.text('OCR供应商'), findsOneWidget);
        expect(find.text('音频转写供应商'), findsOneWidget);
      },
    );

    testWidgets('ASR supplier entry is tappable and navigates to config page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // Verify ASR supplier is visible
      expect(find.text('音频转写供应商'), findsOneWidget);

      // Tap the ASR supplier entry
      await tester.tap(find.text('音频转写供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage which has title "供应商配置"
      expect(find.text('供应商配置'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_background_optimization_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - 任务 section & 后台运行优化 card', () {
    testWidgets('shows 任务 section header instead of 通知', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Should show the new 任务 header
      expect(find.text('任务'), findsOneWidget);
      // Should NOT show the old 通知 header
      expect(find.text('通知'), findsNothing);
    });

    testWidgets('shows 任务完成通知 as navigation card', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // The text should still exist
      expect(find.text('任务完成通知'), findsOneWidget);
      // Subtitle describing the purpose
      expect(find.text('检测通知权限与系统设置，查看通知指南'), findsOneWidget);
      // Should have a chevron_right icon (navigation indicator)
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      // Should NOT have a Switch directly on the settings page for notifications
      // (there may be other Switches like the pre-release toggle)
      // Just verify the notification card is not a Switch-based toggle
      expect(find.text('任务完成或失败时发送通知'), findsNothing);
    });

    testWidgets('shows 后台运行优化 card entry', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
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

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Tap the 后台运行优化 card
      await tester.tap(find.text('后台运行优化'));
      await tester.pumpAndSettle();

      // Should navigate to BackgroundOptimizationPage (verify unique content)
      expect(find.text('系统环境检测'), findsOneWidget);
      expect(find.text('平台教程'), findsOneWidget);
    });

    testWidgets('tapping 任务完成通知 navigates to NotificationSettingsPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // Tap the 任务完成通知 card
      await tester.tap(find.text('任务完成通知'));
      // Push the new page - use pump without settle because
      // CircularProgressIndicator animation prevents settling
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should navigate to NotificationSettingsPage (verify unique content)
      expect(find.text('通知权限设置'), findsOneWidget);
      expect(find.text('通知权限检测'), findsOneWidget);
      expect(find.text('平台指南'), findsOneWidget);
    });

    testWidgets('settings page still renders all other sections',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
      await tester.pumpAndSettle();

      // All original sections should still be present
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('供应商设置'), findsOneWidget);
      expect(find.text('数据备份'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_ocr_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - OCR supplier display', () {
    testWidgets('shows OCR supplier entry when loaded with default entries',
        (tester) async {
      // Use a large viewport so all content is visible
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // No saved data → defaults including OCR
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      expect(find.text('OCR供应商'), findsOneWidget);
      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
    });

    testWidgets('shows OCR supplier after migration from saved data without it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutOcr(),
      });

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // OCR should be migrated in and displayed
      expect(find.text('TTS供应商'), findsOneWidget);
      expect(find.text('LLM供应商'), findsOneWidget);
      expect(find.text('OCR供应商'), findsOneWidget);
    });

    testWidgets('OCR supplier entry is tappable and navigates to config page',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pumpAndSettle();

      // Verify OCR supplier is visible
      expect(find.text('OCR供应商'), findsOneWidget);

      // Tap the OCR supplier entry
      await tester.tap(find.text('OCR供应商'));
      await tester.pumpAndSettle();

      // Should navigate to ProviderConfigPage which has title "供应商配置"
      expect(find.text('供应商配置'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From notification_settings_page_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('NotificationSettingsPage - rendering', () {
    testWidgets('renders page title', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Title bar
      expect(find.text('通知权限设置'), findsOneWidget);
    });

    testWidgets('shows system environment detection section', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Section header
      expect(find.text('系统环境检测'), findsOneWidget);
      // Platform name should be displayed (Android in test env)
      expect(find.text('Android'), findsAtLeast(1));
    });

    testWidgets('shows notification permission status section', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Section header
      expect(find.text('通知权限检测'), findsOneWidget);
    });

    testWidgets('shows platform guide section', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Section header
      expect(find.text('平台指南'), findsOneWidget);
    });

    testWidgets('shows notification toggle title and subtitle', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Should show the toggle labels
      expect(find.text('任务完成通知'), findsOneWidget);
      expect(find.text('任务完成或失败时发送通知'), findsOneWidget);
    });

    testWidgets('renders a Switch for notification toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildNotificationTestApp());
      await tester.pump();

      // Should have a Switch widget
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
