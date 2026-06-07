import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/providers/camera_settings_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

/// Creates a mock [Dio] that returns the given [jsonResponse].
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
          data: jsonResponse,
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
String _githubRelease(String tagName, {String body = '', String? htmlUrl}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  return '''
{
  "tag_name": "$tagName",
  "body": "$body",
  "html_url": "$htmlUrl"
}
''';
}

/// Builds the test app with all required provider overrides.
Widget _buildTestApp({Dio? dio}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      cameraSettingsProvider.overrideWith((ref) => CameraSettingsNotifier()),
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

/// Creates a [ProviderContainer] with all required provider overrides.
ProviderContainer _createContainer({Dio? dio}) {
  return ProviderContainer(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      cameraSettingsProvider.overrideWith((ref) => CameraSettingsNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) => ProviderEntriesNotifier(),
      ),
      updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
    ],
  );
}

void main() {
  /// Sets up a large test surface and scrolls to the "检查更新" button.
  Future<void> setUpAndScrollToUpdateButton(WidgetTester tester, {Dio? dio}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_buildTestApp(dio: dio));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('检查更新'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
  }

  group('SettingsPage - Update Check', () {
    testWidgets('shows update check button', (tester) async {
      await setUpAndScrollToUpdateButton(tester, dio: _createMockDio(_githubRelease('v0.2.13')));

      expect(find.text('检查更新'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('shows checking snackbar with spinner when check starts', (tester) async {
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
      await setUpAndScrollToUpdateButton(tester, dio: _createMockDio(_githubRelease('v0.2.13')));

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('已是最新版本'), findsOneWidget);
    });

    testWidgets('shows update dialog when new version available', (tester) async {
      await setUpAndScrollToUpdateButton(tester, dio: _createMockDio(_githubRelease('v0.2.14', body: 'Bug fixes')));

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

      SharedPreferences.setMockInitialValues({});
      final container = _createContainer(dio: _createMockDio(_githubRelease('v0.2.14')));

      await container.read(updateProvider.notifier).checkForUpdate();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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

      container.dispose();
    });

    testWidgets('update dialog shows skip and remind buttons', (tester) async {
      await setUpAndScrollToUpdateButton(tester, dio: _createMockDio(_githubRelease('v0.2.14')));

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
      await tester.pumpWidget(_buildTestApp(dio: _createMockDio(_githubRelease('v0.2.14'))));
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
}
