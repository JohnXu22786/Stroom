import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/locale_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/providers/theme_provider.dart';

/// Creates a mock [Dio] that returns the given [jsonResponse] wrapped in
/// a list (matching the [/releases] array response from the unified endpoint).
Dio _createMockDio(String jsonResponse, {int statusCode = 200}) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: statusCode,
          data: statusCode == 200
              ? jsonDecode('[$jsonResponse]') as List<dynamic>
              : jsonResponse,
        ),
      );
    },
  ));
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(String tagName,
    {String body = '',
    String? htmlUrl,
    List<Map<String, String>>? assets,
    String publishedAt = '2024-01-15T10:00:00Z'}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  final assetsJson = assets != null
      ? ',\n  "assets": [${assets.map((a) => '{\n      "name": "${a['name']}",\n      "browser_download_url": "${a['browser_download_url']}"\n    }').join(',\n    ')}]'
      : '';
  return '''
{
  "tag_name": "$tagName",
  "published_at": "$publishedAt",
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

/// Builds the test app matching the real app structure:
/// ProviderScope > Application (no outer MaterialApp wrapper).
///
/// In the real app, [Application] IS the root widget that returns
/// a [MaterialApp] from its build() method. The startup update check
/// runs in [Application.initState]. showDialog must use the
/// MaterialApp's navigatorKey.currentContext (not the outer context)
/// because the Application widget lives ABOVE the Navigator.
Widget _buildTestApp({Dio? dio}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
    ],
    child: const Application(),
  );
}

/// Pumps the test app through the full startup flow.
///
/// Sets initial preferences with [dataFormatVersion] (default 2 = current)
/// so migration is skipped, allowing the test to focus on update check behavior.
///
/// [extraPrefs] allows setting additional SharedPreferences keys.
Future<void> _pumpThroughStartup(WidgetTester tester,
    {required Dio dio,
    int dataFormatVersion = 2,
    Map<String, Object>? extraPrefs}) async {
  final prefs = <String, Object>{
    'data_format_version': dataFormatVersion,
    localePreferenceKey: 'zh_CN',
  };
  if (extraPrefs != null) {
    prefs.addAll(extraPrefs);
  }
  SharedPreferences.setMockInitialValues(prefs);
  final expectedLocale = localeFromCode(prefs[localePreferenceKey] as String);

  // Let Application load its saved locale before startup dialogs are allowed
  // to run, so their labels are deterministic in tests.
  startupReadyNotifier.value = false;
  await tester.pumpWidget(_buildTestApp(dio: dio));
  var localeLoaded = false;
  for (int i = 0; i < 20 && !localeLoaded; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    localeLoaded =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale ==
            expectedLocale;
  }
  expect(localeLoaded, isTrue, reason: 'saved app locale should load');

  startupReadyNotifier.value = true;
  await tester.pump();
  // Process post-frame callback → _performStartupChecks starts
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();

  // Update dialog should appear if new version available
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 启动后任务标记是进程级的（错误边界重试不重复执行），
    // 每个测试用例需要复位以获得完整的启动后流程。
    resetPostStartupTasksFlag();
    startupReadyNotifier.value = false;
    setPendingRestartInMemory(false);
  });

  group('Application - Startup Update Check', () {
    testWidgets('post-update restart dialog follows the saved app locale',
        (tester) async {
      addTearDown(() {
        setPendingRestartInMemory(false);
        startupReadyNotifier.value = false;
      });

      setPendingRestartInMemory(true);
      final dio = _createMockDio(_githubRelease('v0.2.13'));

      await _pumpThroughStartup(tester, dio: dio, extraPrefs: {
        localePreferenceKey: 'en_US',
        pendingUpdateRestartKey: true,
      });

      // The test binding starts in the resumed state; transition through
      // paused so the resumed observer callback is delivered.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      var dialogShown = false;
      for (int i = 0; i < 20 && !dialogShown; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        dialogShown = tester.any(find.text('App updated'));
      }

      expect(
        dialogShown,
        isTrue,
        reason: 'warm resume should show restart dialog',
      );
      expect(find.text('App updated'), findsOneWidget);
      expect(
        find.text(
          'The app has been updated. Restart the app to ensure stability.',
        ),
        findsOneWidget,
      );
      expect(find.text('Restart Later'), findsOneWidget);
      expect(find.text('Restart Now'), findsOneWidget);
    });

    testWidgets('shows update dialog on startup when new version available',
        (tester) async {
      final dio = _createMockDio(
        _githubRelease('v0.2.14',
            body: 'New features', assets: _allPlatformAssets('v0.2.14')),
      );

      await _pumpThroughStartup(tester, dio: dio);

      // The update dialog should appear
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('最新版本: 0.2.14'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
    });

    testWidgets(
        'shows no dialog on startup when current version matches latest',
        (tester) async {
      final dio = _createMockDio(
        _githubRelease('v0.2.13'), // Same as appVersion
      );

      await _pumpThroughStartup(tester, dio: dio);

      // No dialog should appear
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('shows no dialog on startup when version was skipped',
        (tester) async {
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      await _pumpThroughStartup(tester, dio: dio, extraPrefs: {
        'update_skipped_version': '0.2.14',
      });

      // No dialog should appear (version was skipped)
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('shows no dialog on startup when API call fails',
        (tester) async {
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
        statusCode: 500,
      );

      await _pumpThroughStartup(tester, dio: dio);

      // No dialog should appear (silent error)
      expect(find.text('发现新版本'), findsNothing);
    });
  });
}
