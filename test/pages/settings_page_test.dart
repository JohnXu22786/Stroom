// Merged from:
//   test/pages/settings_page_asr_test.dart
//   test/pages/settings_page_background_optimization_test.dart
//   test/pages/settings_page_camera_test.dart
//   test/pages/settings_page_license_test.dart
//   test/pages/settings_page_ocr_test.dart
//   test/pages/settings_page_update_test.dart
//   test/pages/notification_settings_page_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

/// Builds the SettingsPage test app for the update-check group (accepts a [Dio]).
Widget _buildUpdateTestApp({Dio? dio}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) => ProviderEntriesNotifier(),
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
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

/// Creates a mock [Dio] that returns the given [jsonResponse].
///
/// The [jsonResponse] string is pre-parsed into a [Map] before setting it on the
/// response, simulating real Dio's JSON auto-parsing behavior (ResponseType.json).
Dio _createMockDio(String jsonResponse, {bool noDelay = true}) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (!noDelay) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: jsonDecode(jsonResponse) as Map<String, dynamic>,
        ),
      );
    },
  ));
  return dio;
}

/// Creates a mock [Dio] that always fails.
Dio _createFailingDio() {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        message: 'Connection refused',
        type: DioExceptionType.connectionTimeout,
      ));
    },
  ));
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(String tagName,
    {String body = '', String? htmlUrl, List<Map<String, String>>? assets}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  final assetsJson = assets != null
      ? ',\n  "assets": [${assets.map((a) => '{\n      "name": "${a['name']}",\n      "browser_download_url": "${a['browser_download_url']}"\n    }').join(',\n    ')}]'
      : '';
  return '''
{
  "tag_name": "$tagName",
  "body": "$body",
  "html_url": "$htmlUrl"$assetsJson
}
''';
}

/// Build a list of release assets for all platforms.
List<Map<String, String>> _allPlatformAssets(String tagName) {
  final version = tagName.replaceAll(RegExp(r'^v'), '');
  return [
    {
      'name': 'stroom-android-release-v$version.apk',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-android-release-v$version.apk'
    },
    {
      'name': 'stroom-windows-x64-installer-v$version.exe',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-windows-x64-installer-v$version.exe'
    },
    {
      'name': 'stroom-macos-arm64-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-macos-arm64-release-v$version.zip'
    },
    {
      'name': 'stroom-linux-x64-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-linux-x64-release-v$version.zip'
    },
    {
      'name': 'stroom-web-release-v$version.zip',
      'browser_download_url':
          'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-web-release-v$version.zip'
    },
  ];
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
  // From settings_page_camera_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - Camera section removed', () {
    testWidgets('does NOT show save to gallery setting', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
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

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
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

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
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

      await tester.pumpWidget(_buildSettingsTestAppWithNotification());
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

  // ─────────────────────────────────────────────────────────────────────
  // From settings_page_license_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - License Display', () {
    testWidgets('shows AGPLv3 open source license subtitle', (tester) async {
      // Set a large screen so all items are visible without scrolling
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildSettingsTestApp());
      await tester.pump();

      // Scroll down to the "关于" section
      await tester.scrollUntilVisible(
        find.text('开源协议'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      // Verify the license subtitle shows AGPLv3
      expect(
        find.text('GNU Affero General Public License v3.0'),
        findsOneWidget,
      );

      // Verify the old GPLv3 text is NOT present
      expect(
        find.text('GNU General Public License v3.0'),
        findsNothing,
      );
    });
  });

  group('LICENSE file', () {
    test('contains AGPLv3 header', () {
      final licenseFile = File('LICENSE');
      expect(licenseFile.existsSync(), isTrue);

      final content = licenseFile.readAsStringSync();
      expect(content, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      expect(content, contains('Version 3, 19 November 2007'));
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
  // From settings_page_update_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SettingsPage - Update Check', () {
    /// Sets up a large test surface and scrolls to the "检查更新" button.
    Future<void> setUpAndScrollToUpdateButton(WidgetTester tester,
        {Dio? dio}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildUpdateTestApp(dio: dio));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('检查更新'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
    }

    testWidgets('shows update check button', (tester) async {
      await setUpAndScrollToUpdateButton(tester,
          dio: _createMockDio(_githubRelease('v0.2.13')));

      expect(find.text('检查更新'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('shows checking snackbar with spinner when check starts',
        (tester) async {
      await setUpAndScrollToUpdateButton(
        tester,
        dio: _createMockDio(_githubRelease('v0.2.13'), noDelay: false),
      );

      await tester.tap(find.text('检查更新'));
      await tester.pump();
      expect(find.text('正在检查更新...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('正在检查更新...'), findsNothing);
      expect(find.text('已是最新版本'), findsOneWidget);
    });

    testWidgets('shows "已是最新版本" when no update available', (tester) async {
      await setUpAndScrollToUpdateButton(tester,
          dio: _createMockDio(_githubRelease('v0.2.13')));

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('已是最新版本'), findsOneWidget);
    });

    testWidgets('shows update dialog when new version available',
        (tester) async {
      await setUpAndScrollToUpdateButton(
        tester,
        dio: _createMockDio(_githubRelease('v0.2.14',
            body: 'Bug fixes', assets: _allPlatformAssets('v0.2.14'))),
      );

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('最新版本: 0.2.14'), findsOneWidget);
      expect(find.text('Bug fixes'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
    });

    testWidgets('shows network error when HTTP fails', (tester) async {
      await setUpAndScrollToUpdateButton(tester, dio: _createFailingDio());

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.textContaining('网络错误'), findsOneWidget);
    });

    testWidgets('shows "新版本" badge when update is available', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a ProviderScope with pre-set update state using ProviderContainer
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
          _githubRelease('v0.2.14', assets: _allPlatformAssets('v0.2.14')));
      final notifier = UpdateNotifier(dio: dio);

      // Directly set the state to simulate an available update (bypass HTTP call)
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/stroom-windows-x64-installer-v0.2.14.exe',
        releaseNotes: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith((ref) => ThemeNotifier()),
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('检查更新'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      expect(find.text('新版本'), findsOneWidget);
      expect(find.textContaining('发现新版本'), findsOneWidget);
    });

    testWidgets('update dialog shows skip and remind buttons', (tester) async {
      await setUpAndScrollToUpdateButton(tester,
          dio: _createMockDio(_githubRelease('v0.2.14',
              assets: _allPlatformAssets('v0.2.14'))));

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
    });

    testWidgets('shows "已是最新版本" when update was skipped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'update_skipped_version': '0.2.14',
      });
      await tester.pumpWidget(_buildUpdateTestApp(
          dio: _createMockDio(_githubRelease('v0.2.14',
              assets: _allPlatformAssets('v0.2.14')))));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('检查更新'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('已是最新版本'), findsOneWidget);
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
