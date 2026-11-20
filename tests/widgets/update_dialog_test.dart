import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/update_dialog.dart';

/// Wraps the given [notifier] and shows [UpdateDialog] via [showDialog],
/// then pumps until settled.
Future<void> _showDialog({
  required WidgetTester tester,
  required UpdateNotifier notifier,
  Locale locale = const Locale('zh', 'CN'),
  Size? size,
  ThemeData? theme,
}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [updateProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        locale: locale,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
UpdateNotifier _setupNotifier({required UpdateState state}) {
  final notifier = UpdateNotifier(
    dio: _createMockDio(_githubRelease('v0.2.14')),
  );
  notifier.state = state;
  return notifier;
}

/// Creates a mock [Dio] that returns the given [jsonResponse] wrapped in
/// a list (matching the [/releases] array response from the unified endpoint).
Dio _createMockDio(String jsonResponse) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(
    InterceptorsWrapper(
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
    ),
  );
  return dio;
}

/// Build a GitHub releases API response for the given tag.
String _githubRelease(
  String tagName, {
  String body = '',
  String? htmlUrl,
  String publishedAt = '2024-01-15T10:00:00Z',
}) {
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

void _expectStatusClips(WidgetTester tester, Finder status) {
  final widget = tester.widget<ConstrainedText>(status);
  final context = tester.element(status);
  final painter = TextPainter(
    text: TextSpan(
      text: widget.data,
      style: DefaultTextStyle.of(context).style.merge(widget.style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.localeOf(context),
    maxLines: widget.maxLines,
  )..layout();

  expect(painter.width, greaterThan(tester.getSize(status).width));
}

void main() {
  group('UpdateDialog - Shared Dialog', () {
    testWidgets('bounds the completed download status at large text scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: '0.5.5',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          downloadComplete: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('de', 'DE'),
        size: const Size(320, 640),
        theme: ThemeData.light(),
      );

      final status = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == 'Download abgeschlossen',
      );
      expect(status, findsOneWidget);
      _expectStatusClips(tester, status);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bounds the installing status at large text scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: '0.5.5',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          downloadComplete: true,
          isInstalling: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('de', 'DE'),
        size: const Size(320, 640),
        theme: ThemeData.dark(),
      );

      final status = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == 'Wird installiert…',
      );
      expect(status, findsOneWidget);
      _expectStatusClips(tester, status);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not expose manual release selection', (tester) async {
      final notifier = _setupNotifier(
        state: UpdateState(
          latestVersion: '0.5.5',
          releaseNotes: 'Latest fixes',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          availableVersions: [
            const AvailableUpdate(
              version: '0.5.5',
              releaseNotes: 'Latest fixes',
              downloadUrl: 'https://example.com/latest.zip',
            ),
            const AvailableUpdate(
              version: '0.5.4',
              releaseNotes: 'Older fixes',
              downloadUrl: 'https://example.com/older.zip',
            ),
          ],
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
      );

      expect(find.text('Latest version: 0.5.5'), findsOneWidget);
      expect(find.text('v0.5.5'), findsNothing);
      expect(find.text('v0.5.4'), findsNothing);
      expect(find.text('Older fixes'), findsNothing);
      expect(find.text('Update now'), findsOneWidget);
      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows byte progress and fixed cancel/background actions', (
      tester,
    ) async {
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: '0.5.5',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          isDownloading: true,
          downloadProgress: 0.5,
          downloadReceivedBytes: 512,
          downloadTotalBytes: 1024,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
      );

      expect(find.text('512 B / 1.0 KB  ·  50%'), findsOneWidget);
      expect(find.text('Cancel download'), findsOneWidget);
      expect(find.text('Download in background'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Download in background'));
      await tester.pumpAndSettle();
      expect(notifier.state.downloadInBackground, true);
      expect(find.byType(UpdateDialog), findsNothing);
    });

    testWidgets('download actions fit narrow dark dialogs with larger text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: '0.5.5',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          isDownloading: true,
          downloadProgress: 0.5,
          downloadReceivedBytes: 1024,
          downloadTotalBytes: 2048,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
        size: const Size(280, 760),
        theme: ThemeData.dark(),
      );

      expect(find.text('Cancel download'), findsOneWidget);
      expect(find.text('Download in background'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('download actions use the selected locale', (tester) async {
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: '0.5.5',
          downloadUrl: 'https://example.com/latest.zip',
          updateAvailable: true,
          isDownloading: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('es', 'ES'),
        size: const Size(900, 800),
      );

      expect(find.text('Cancelar descarga'), findsOneWidget);
      expect(find.text('Descargar en segundo plano'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone layout gives the primary action a full-width target', (
      tester,
    ) async {
      final notifier = _setupNotifier(
        state: UpdateState(
          latestVersion: 'v0.5.5',
          releaseNotes: List.filled(
            20,
            'A long release note that needs a readable scrolling area. ',
          ).join(),
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.5.5/Stroom.apk',
          updateAvailable: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
        size: const Size(390, 844),
      );

      final primaryAction = find.ancestor(
        of: find.text('Update now'),
        matching: find.byType(FilledButton),
      );
      final actionArea = find
          .ancestor(
            of: primaryAction,
            matching: find.byType(OverflowBar),
          )
          .first;
      final primaryRect = tester.getRect(primaryAction);
      expect(
        primaryRect.width,
        greaterThanOrEqualTo(tester.getSize(actionArea).width * 0.65),
      );
      expect(
        primaryRect.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AlertDialog)).bottom),
      );

      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
    });

    testWidgets('very narrow phones stack all actions without wrapping', (
      tester,
    ) async {
      final notifier = _setupNotifier(
        state: UpdateState(
          latestVersion: 'v0.5.5',
          releaseNotes: List.filled(
            20,
            'A long release note with a URL that needs a readable scrolling area. ',
          ).join(),
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.5.5/Stroom.apk',
          updateAvailable: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
        size: const Size(280, 760),
      );

      final skipButton = find.ancestor(
        of: find.text('Skip this version'),
        matching: find.byType(TextButton),
      );
      final remindButton = find.ancestor(
        of: find.text('Remind me later'),
        matching: find.byType(TextButton),
      );
      final primaryButton = find.ancestor(
        of: find.text('Update now'),
        matching: find.byType(FilledButton),
      );
      final skipRect = tester.getRect(skipButton.first);
      final remindRect = tester.getRect(remindButton.first);
      final primaryRect = tester.getRect(primaryButton.first);

      expect(skipRect.bottom, lessThanOrEqualTo(remindRect.top));
      expect(remindRect.bottom, lessThanOrEqualTo(primaryRect.top));
      expect(skipRect.width, greaterThanOrEqualTo(primaryRect.width * 0.9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('larger text stacks secondary actions on a regular phone', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: 'v0.5.5',
          releaseNotes:
              '## What\'s Changed\n* A long release note with a URL that remains scrollable.',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/download/v0.5.5/Stroom.apk',
          updateAvailable: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
        size: const Size(390, 844),
      );

      final skipRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Skip this version'),
              matching: find.byType(TextButton),
            )
            .first,
      );
      final remindRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Remind me later'),
              matching: find.byType(TextButton),
            )
            .first,
      );
      final primaryRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Update now'),
              matching: find.byType(FilledButton),
            )
            .first,
      );

      expect(skipRect.bottom, lessThanOrEqualTo(remindRect.top));
      expect(remindRect.bottom, lessThanOrEqualTo(primaryRect.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels follow the selected locale', (tester) async {
      final notifier = _setupNotifier(
        state: const UpdateState(
          latestVersion: 'v0.2.14',
          downloadUrl:
              'https://github.com/JohnXu22786/Stroom/releases/tag/v0.2.14',
          updateAvailable: true,
        ),
      );
      await _showDialog(
        tester: tester,
        notifier: notifier,
        locale: const Locale('en', 'US'),
      );

      expect(find.text('New version available'), findsOneWidget);
      expect(find.text('Latest version: v0.2.14'), findsOneWidget);
      expect(find.text('Skip this version'), findsOneWidget);
      expect(find.text('Remind me later'), findsOneWidget);
      expect(find.text('Download in browser'), findsOneWidget);
      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
    });

    testWidgets('skip button calls skipVersion and closes dialog', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));

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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('later button closes dialog without side effects', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));

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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      final dio = _createMockDio(_githubRelease('v0.2.14'));

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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      expect(find.text('0 B'), findsOneWidget);
      // The "立即更新" button should NOT be visible during download
      expect(find.text('立即更新'), findsNothing);
      // Skip and remind buttons should NOT be visible during download
      expect(find.text('跳过此版本'), findsNothing);
      expect(find.text('稍后提醒'), findsNothing);
    });

    testWidgets('shows installing state UI when isInstalling is true', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));

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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('shows fallback install button when auto-install fails', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dio = _createMockDio(_githubRelease('v0.2.14'));

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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('dialog cannot be dismissed by popping while downloading', (
      tester,
    ) async {
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
      );

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

    testWidgets('dialog cannot be dismissed by popping while installing', (
      tester,
    ) async {
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
      );

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
        );

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
      },
    );

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
      );

      await _showDialog(tester: tester, notifier: notifier);

      // Tap "打开安装包" button
      await tester.tap(find.text('打开安装包'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After tapping, isInstalling should be true (retryInstall sets it)
      expect(notifier.state.isInstalling, true);
    });
  });

  group('UpdateDialog - Automatic version selection', () {
    testWidgets(
      'shows the provider default release without a picker',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            updateProvider.overrideWith(
              (ref) => UpdateNotifier(dio: Dio(BaseOptions())),
            ),
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
            overrides: [updateProvider.overrideWith((ref) => notifier)],
            child: MaterialApp(
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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

        expect(find.text('v0.2.16'), findsNothing);
        expect(find.text('v0.2.15'), findsNothing);
        expect(find.text('最新版本: 0.2.16'), findsOneWidget);
        expect(notifier.state.latestVersion, '0.2.16');
      },
    );

    testWidgets('keeps the default release and URL aligned', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith(
            (ref) => UpdateNotifier(dio: Dio(BaseOptions())),
          ),
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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      expect(find.text('v0.2.15'), findsNothing);
      expect(notifier.state.selectedVersionIndex, 0);
      expect(notifier.state.latestVersion, '0.2.16');
      expect(notifier.state.releaseNotes, 'Version 0.2.16 notes');
      expect(notifier.state.downloadUrl, 'https://example.com/v0.2.16.zip');
    });

    testWidgets('single version dialog still works (backward compat)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          updateProvider.overrideWith(
            (ref) => UpdateNotifier(dio: Dio(BaseOptions())),
          ),
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
          overrides: [updateProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
