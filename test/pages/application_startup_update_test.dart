import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/application.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/providers/theme_provider.dart';

/// Creates a mock [Dio] that returns the given [jsonResponse].
Dio _createMockDio(String jsonResponse, {int statusCode = 200}) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: statusCode,
          data: statusCode == 200
              ? jsonDecode(jsonResponse) as Map<String, dynamic>
              : jsonResponse,
        ),
      );
    },
  ));
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(String tagName, {String body = '', String? htmlUrl, List<Map<String, String>>? assets}) {
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
    {'name': 'stroom-android-release-v$version.apk', 'browser_download_url': 'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-android-release-v$version.apk'},
    {'name': 'stroom-windows-x64-release-v$version.zip', 'browser_download_url': 'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-windows-x64-release-v$version.zip'},
    {'name': 'stroom-macos-arm64-release-v$version.zip', 'browser_download_url': 'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-macos-arm64-release-v$version.zip'},
    {'name': 'stroom-linux-x64-release-v$version.zip', 'browser_download_url': 'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-linux-x64-release-v$version.zip'},
    {'name': 'stroom-web-release-v$version.zip', 'browser_download_url': 'https://github.com/JohnXu22786/Stroom/releases/download/$tagName/stroom-web-release-v$version.zip'},
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

void main() {
  group('Application - Startup Update Check', () {
    testWidgets('shows update dialog on startup when new version available', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14', body: 'New features', assets: _allPlatformAssets('v0.2.14')),
      );

      await tester.pumpWidget(_buildTestApp(dio: dio));
      // Wait for post-frame callback and update check
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // The update dialog should appear
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('最新版本: 0.2.14'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
    });

    testWidgets('shows no dialog on startup when current version matches latest', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.13'), // Same as appVersion
      );

      await tester.pumpWidget(_buildTestApp(dio: dio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // No dialog should appear
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('shows no dialog on startup when version was skipped', (tester) async {
      SharedPreferences.setMockInitialValues({
        'update_skipped_version': '0.2.14',
      });
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      await tester.pumpWidget(_buildTestApp(dio: dio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // No dialog should appear (version was skipped)
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('shows no dialog on startup when API call fails', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
        statusCode: 500,
      );

      await tester.pumpWidget(_buildTestApp(dio: dio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // No dialog should appear (silent error)
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('dialog has same UI elements as manual check dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14', body: 'Bug fixes and improvements', assets: _allPlatformAssets('v0.2.14')),
      );

      await tester.pumpWidget(_buildTestApp(dio: dio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Same elements as the manual check dialog in settings_page
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('最新版本: 0.2.14'), findsOneWidget);
      expect(find.text('更新内容:'), findsOneWidget);
      expect(find.text('Bug fixes and improvements'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });
  });
}
