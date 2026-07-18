import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/widgets/update_dialog.dart';

/// Wraps the given [notifier] and shows [UpdateDialog] via [showDialog],
/// then pumps until settled.
Future<void> _showDialog({
  required WidgetTester tester,
  required UpdateNotifier notifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            Future.microtask(() {
              showDialog(
                context: context,
                builder: (_) => const UpdateDialog(),
              );
            });
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Sets up an [UpdateNotifier] with a mock Dio and given [state].
({UpdateNotifier notifier, ProviderContainer container}) _setupNotifier({
  required UpdateState state,
}) {
  final dio = _createMockDio(_githubRelease('v0.2.14'));
  final container = ProviderContainer(
    overrides: [
      updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
    ],
  );
  final notifier = container.read(updateProvider.notifier);
  notifier.state = state;
  return (notifier: notifier, container: container);
}

/// Creates a mock [Dio] that returns the given [jsonResponse] wrapped in
/// a list (matching the [/releases] array response from the unified endpoint).
Dio _createMockDio(String jsonResponse) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // For GET requests (checkForUpdate), use the interceptor
      if (options.method == 'GET') {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: jsonDecode('[$jsonResponse]') as List<dynamic>,
          ),
        );
      } else {
        handler.next(options);
      }
    },
  ));
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(String tagName,
    {String body = '',
    String? htmlUrl,
    String publishedAt = '2024-01-15T10:00:00Z'}) {
  htmlUrl ??= 'https://github.com/JohnXu22786/Stroom/releases/tag/$tagName';
  return '''
{
  "tag_name": "$tagName",
  "published_at": "$publishedAt",
  "body": "$body",
  "html_url": "$htmlUrl"
}
''';
}

void main() {
  group('UpdateDialog - Shared Dialog', () {
    testWidgets('shows update dialog with all elements when update available',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14', body: 'Bug fixes'),
      );

      // Set up the state to show an update is available
      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        releaseNotes: 'Bug fixes',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
      );

      // Show the dialog programmatically
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Use a Future.microtask to show dialog after initial build
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog elements
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('最新版本: 0.2.14'), findsOneWidget);
      expect(find.text('更新内容:'), findsOneWidget);
      expect(find.text('Bug fixes'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
    });

    testWidgets('skip button calls skipVersion and closes dialog',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap skip button
      await tester.tap(find.text('跳过此版本'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('发现新版本'), findsNothing);

      // State should be reset
      expect(notifier.state.updateAvailable, false);
    });

    testWidgets('later button closes dialog without side effects',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap later button
      await tester.tap(find.text('稍后提醒'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('发现新版本'), findsNothing);

      // State should remain (not cleared)
      expect(notifier.state.updateAvailable, true);
    });

    testWidgets('shows download progress bar when downloading', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        isDownloading: true,
        downloadProgress: 0.45,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify progress bar and percentage text
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('正在下载更新...'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      // The "立即更新" button should NOT be visible during download
      expect(find.text('立即更新'), findsNothing);
      // Skip and remind buttons should NOT be visible during download
      expect(find.text('跳过此版本'), findsNothing);
      expect(find.text('稍后提醒'), findsNothing);
    });

    testWidgets('shows installing state UI when isInstalling is true',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        downloadComplete: true,
        isInstalling: true,
        downloadedFilePath: '/tmp/test.apk',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show installing text
      expect(find.text('正在安装...'), findsOneWidget);
      // Should NOT show any action buttons (auto-installing)
      expect(find.text('关闭'), findsNothing);
      expect(find.text('手动安装'), findsNothing);
    });

    testWidgets('shows fallback install button when auto-install fails',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(
        _githubRelease('v0.2.14'),
      );

      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith((ref) => UpdateNotifier(dio: dio)),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        latestVersion: '0.2.14',
        downloadUrl:
            'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
        downloadComplete: true,
        isInstalling: false,
        downloadError: '安装失败，请手动打开 APK 安装',
        downloadedFilePath: '/tmp/test.apk',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show download complete message
      expect(find.text('下载完成'), findsOneWidget);
      // Should show manual install button that retries local APK installation
      expect(find.text('手动安装'), findsOneWidget);
      // Should also show the error
      expect(find.text('安装失败，请手动打开 APK 安装'), findsOneWidget);
    });

    testWidgets('dialog cannot be dismissed by popping while downloading',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
          isDownloading: true,
          downloadProgress: 0.5,
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Verify the dialog is visible
      expect(find.text('正在下载更新...'), findsOneWidget);

      // Try to pop the dialog (simulate back button or barrier dismiss)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog should still be visible — not dismissed
      expect(find.text('正在下载更新...'), findsOneWidget);
    });

    testWidgets('dialog cannot be dismissed by popping while installing',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
          downloadComplete: true,
          isInstalling: true,
          downloadedFilePath: '/tmp/test.exe',
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Verify the dialog is visible
      expect(find.text('正在安装...'), findsOneWidget);

      // Try to pop the dialog
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog should still be visible
      expect(find.text('正在安装...'), findsOneWidget);
    });

    testWidgets(
        'dialog does NOT auto-close after download complete with no error',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
          downloadComplete: true,
          isDownloading: false,
          isInstalling: false,
          downloadError: null,
          downloadedFilePath: '/tmp/test.exe',
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Pump multiple frames to ensure any auto-close logic would have fired
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();

      // Dialog should still be open with the "下载完成" message
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);

      // User can close it manually
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsNothing);
    });

    testWidgets('dialog shows download-complete state and does not auto-close',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.zip',
          downloadComplete: true,
          isDownloading: false,
          isInstalling: false,
          downloadError: null,
          downloadedFilePath: '/tmp/test.exe',
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Verify the download success state is shown
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // "关闭" button should be shown for manual dismissal
      expect(find.text('关闭'), findsOneWidget);

      // No auto-closing — dialog survives after multiple frames
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('下载完成'), findsOneWidget);
    });

    testWidgets(
        'shows "打开安装包" button when download complete with no error',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.exe',
          downloadComplete: true,
          isDownloading: false,
          isInstalling: false,
          downloadError: null,
          downloadedFilePath: '/tmp/test.exe',
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Verify both buttons are shown
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('打开安装包'), findsOneWidget);
    });

    testWidgets('tapping "打开安装包" calls retryInstall', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = _setupNotifier(
        state: UpdateState(
          updateAvailable: true,
          latestVersion: '0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.2.14/test.exe',
          downloadComplete: true,
          isDownloading: false,
          isInstalling: false,
          downloadError: null,
          downloadedFilePath: '/tmp/test.exe',
        ),
      ).notifier;

      await _showDialog(tester: tester, notifier: notifier);

      // Tap "打开安装包" button
      await tester.tap(find.text('打开安装包'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After tapping, isInstalling should be true (retryInstall sets it)
      expect(notifier.state.isInstalling, true);
    });
  });

  group('UpdateDialog - Multi-version selection', () {
    testWidgets('shows version selection list when multiple versions available',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          updateProvider
              .overrideWith((ref) => UpdateNotifier(dio: Dio(BaseOptions()))),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        availableVersions: [
          AvailableUpdate(
            version: '0.2.16',
            releaseNotes: 'Version 0.2.16',
            downloadUrl: 'https://example.com/v0.2.16.zip',
            isPreRelease: false,
          ),
          AvailableUpdate(
            version: '0.2.15',
            releaseNotes: 'Version 0.2.15',
            downloadUrl: 'https://example.com/v0.2.15.zip',
            isPreRelease: false,
          ),
        ],
        selectedVersionIndex: 0,
        latestVersion: '0.2.16',
        releaseNotes: 'Version 0.2.16',
        downloadUrl: 'https://example.com/v0.2.16.zip',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show version selection items (prefixed with 'v' in the list)
      expect(find.text('v0.2.16'), findsOneWidget);
      expect(find.text('v0.2.15'), findsOneWidget);
      // Should show the currently selected version in header
      expect(find.textContaining('0.2.16'), findsWidgets);
    });

    testWidgets('tapping a version in list selects it and updates display',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          updateProvider
              .overrideWith((ref) => UpdateNotifier(dio: Dio(BaseOptions()))),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        availableVersions: [
          AvailableUpdate(
            version: '0.2.16',
            releaseNotes: 'Version 0.2.16 notes',
            downloadUrl: 'https://example.com/v0.2.16.zip',
            isPreRelease: false,
          ),
          AvailableUpdate(
            version: '0.2.15',
            releaseNotes: 'Version 0.2.15 notes',
            downloadUrl: 'https://example.com/v0.2.15.zip',
            isPreRelease: false,
          ),
        ],
        selectedVersionIndex: 0,
        latestVersion: '0.2.16',
        releaseNotes: 'Version 0.2.16 notes',
        downloadUrl: 'https://example.com/v0.2.16.zip',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The header should show the first version (0.2.16)
      expect(find.textContaining('0.2.16'), findsWidgets);

      // Tap the second version in the list (shown as 'v0.2.15')
      await tester.tap(find.text('v0.2.15'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now the header should show the newly selected version (0.2.15)
      expect(notifier.state.selectedVersionIndex, 1);
      expect(notifier.state.latestVersion, '0.2.15');
    });

    testWidgets('single version dialog still works (backward compat)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          updateProvider
              .overrideWith((ref) => UpdateNotifier(dio: Dio(BaseOptions()))),
        ],
      );
      final notifier = container.read(updateProvider.notifier);
      notifier.state = UpdateState(
        updateAvailable: true,
        availableVersions: [
          AvailableUpdate(
            version: '0.2.14',
            releaseNotes: 'Bug fixes',
            downloadUrl: 'https://example.com/v0.2.14.zip',
            isPreRelease: false,
          ),
        ],
        selectedVersionIndex: 0,
        latestVersion: '0.2.14',
        releaseNotes: 'Bug fixes',
        downloadUrl: 'https://example.com/v0.2.14.zip',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (_) => const UpdateDialog(),
                  );
                });
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show all standard elements
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.textContaining('0.2.14'), findsWidgets);
      expect(find.text('Bug fixes'), findsOneWidget);
      // The selection list should exist even with single item
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('跳过此版本'), findsOneWidget);
      expect(find.text('稍后提醒'), findsOneWidget);
    });
  });
}
