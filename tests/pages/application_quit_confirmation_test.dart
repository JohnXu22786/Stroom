import 'dart:convert';
import 'dart:io' show exit;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/application.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/services/desktop_app_service.dart';
import 'package:tray_manager/legacy.dart' show Menu, TrayListener;
import 'package:window_manager/legacy.dart' show WindowListener;

class _NoopDesktopTrayAdapter implements DesktopTrayAdapter {
  _NoopDesktopTrayAdapter({this.failSetIcon = false});

  final bool failSetIcon;

  @override
  Future<void> setIcon(String iconPath) async {
    if (failSetIcon) throw StateError('tray-unavailable');
  }

  @override
  Future<void> setToolTip(String toolTip) async {}

  @override
  Future<void> setContextMenu(Menu menu) async {}

  @override
  Future<void> popUpContextMenu() async {}

  @override
  Future<void> destroy() async {}

  @override
  void addListener(TrayListener listener) {}

  @override
  void removeListener(TrayListener listener) {}
}

void _resetDesktopAppServiceForTest() {
  final service = DesktopAppService.instance;
  service.resetForTesting();
  service.setTrayAdapterForTesting(_NoopDesktopTrayAdapter());
}

class _RecordingDesktopWindowManagerAdapter
    implements DesktopWindowManagerAdapter {
  _RecordingDesktopWindowManagerAdapter({this.failRollbackClear = false});

  final bool failRollbackClear;
  final calls = <MethodCall>[];
  final listeners = <WindowListener>[];

  void _record(String method, [Object? arguments]) {
    calls.add(MethodCall(method, arguments));
    if (failRollbackClear &&
        method == 'setPreventClose' &&
        (arguments as Map)['isPreventClose'] == false) {
      throw PlatformException(code: 'rollback-failed');
    }
  }

  @override
  Future<void> ensureInitialized() async => _record('ensureInitialized');

  @override
  Future<void> setPreventClose(bool isPreventClose) async =>
      _record('setPreventClose', {'isPreventClose': isPreventClose});

  @override
  Future<void> close() async => _record('close');

  @override
  Future<void> hide() async => _record('hide');

  @override
  Future<void> show() async => _record('show');

  @override
  Future<void> focus() async => _record('focus');

  @override
  Future<void> destroy() async => _record('destroy');

  @override
  void addListener(WindowListener listener) {
    listeners.add(listener);
    _record('addListener');
  }

  @override
  void removeListener(WindowListener listener) {
    listeners.remove(listener);
    _record('removeListener');
  }
}

/// Mock [Dio] that resolves every request with the given response
/// (same version as the app → no update dialog during startup).
Dio _createMockDio() {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: jsonDecode(
              '[{"tag_name": "v0.4.47", "published_at": "2024-01-15T10:00:00Z",'
              ' "body": "", "html_url": "https://github.com/JohnXu22786/Stroom"}]',
            ),
          ),
        );
      },
    ),
  );
  return dio;
}

/// Pumps the full [Application] (like the real app root) with the
/// window_manager channel mocked and tray behavior supplied by a fake.
/// Returns the recorded channel calls and the exit codes.
Future<
    ({
      List<MethodCall> windowCalls,
      List<int> exitCodes,
      _RecordingDesktopWindowManagerAdapter windowManager,
    })> _pumpApplication(
  WidgetTester tester, {
  required bool closeMinimizes,
  BackgroundTaskNotifier? taskNotifier,
  bool failTraySetup = false,
  bool failRollbackClear = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'data_format_version': 2, // skip migration
    'desktop_close_minimize': closeMinimizes,
    'app_locale_override': 'zh_CN',
  });

  final windowManager = _RecordingDesktopWindowManagerAdapter(
    failRollbackClear: failRollbackClear,
  );
  DesktopAppService.instance.setWindowManagerAdapterForTesting(windowManager);
  DesktopAppService.instance.setTrayAdapterForTesting(
    _NoopDesktopTrayAdapter(failSetIcon: failTraySetup),
  );

  // Record the process exit instead of actually exiting.
  final exitCodes = <int>[];
  DesktopAppService.exitApp = exitCodes.add;

  final notifier = taskNotifier ?? BackgroundTaskNotifier();

  // 测试中直接泵 Application（无 StartupApp）：手动置位启动就绪标记。
  startupReadyNotifier.value = true;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith((ref) => ThemeNotifier()),
        updateProvider.overrideWith(
          (ref) => UpdateNotifier(dio: _createMockDio()),
        ),
        backgroundTasksProvider.overrideWith((ref) => notifier),
      ],
      child: const TickerMode(enabled: false, child: Application()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();

  return (
    windowCalls: windowManager.calls,
    exitCodes: exitCodes,
    windowManager: windowManager,
  );
}

/// Simulates the native window close event arriving on the
/// window_manager method channel (eventName: 'close').
Future<void> _emitWindowClose(
  WidgetTester tester,
  _RecordingDesktopWindowManagerAdapter windowManager,
) async {
  for (final listener in windowManager.listeners.toList()) {
    listener.onWindowClose();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Restore the real exit function and reset the singleton between tests.
    DesktopAppService.exitApp = exit;
    _resetDesktopAppServiceForTest();
    // 启动后任务标记是进程级的（错误边界重试不重复执行），
    // 每个测试用例需要复位以获得完整的启动后流程。
    resetPostStartupTasksFlag();
    startupReadyNotifier.value = false;
  });

  group('Application - close-to-quit confirmation', () {
    testWidgets('close in minimize mode hides to tray without confirmation', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final ctx = await _pumpApplication(tester, closeMinimizes: true);

        await _emitWindowClose(tester, ctx.windowManager);

        expect(find.text('退出应用？'), findsNothing);
        expect(ctx.windowCalls.where((c) => c.method == 'hide'), hasLength(1));
        expect(ctx.windowCalls.where((c) => c.method == 'destroy'), isEmpty);
        expect(ctx.exitCodes, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _resetDesktopAppServiceForTest();
      }
    });

    testWidgets('close in quit mode with no tasks quits directly', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final ctx = await _pumpApplication(tester, closeMinimizes: false);

        await _emitWindowClose(tester, ctx.windowManager);

        expect(find.text('退出应用？'), findsNothing);
        expect(
          ctx.windowCalls.where((c) => c.method == 'destroy'),
          hasLength(1),
        );
        expect(ctx.exitCodes, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _resetDesktopAppServiceForTest();
      }
    });

    testWidgets(
        'close in quit mode with running tasks asks for confirmation '
        'and cancelling keeps the window open', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(
          tester,
          closeMinimizes: false,
          taskNotifier: notifier,
        );

        await _emitWindowClose(tester, ctx.windowManager);

        // Confirmation dialog appears; cancel keeps the window open.
        expect(find.text('退出应用？'), findsOneWidget);
        expect(find.textContaining('1 个任务正在运行'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(ctx.windowCalls.where((c) => c.method == 'destroy'), isEmpty);
        expect(ctx.exitCodes, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _resetDesktopAppServiceForTest();
      }
    });

    testWidgets('close in quit mode with running tasks quits after confirm', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(
          tester,
          closeMinimizes: false,
          taskNotifier: notifier,
        );

        await _emitWindowClose(tester, ctx.windowManager);

        expect(find.text('退出应用？'), findsOneWidget);
        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();
        expect(
          ctx.windowCalls.where((c) => c.method == 'destroy'),
          hasLength(1),
        );
        expect(ctx.exitCodes, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _resetDesktopAppServiceForTest();
      }
    });

    testWidgets(
        'repeated close events while the dialog is open do not stack '
        'a second dialog', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(
          tester,
          closeMinimizes: false,
          taskNotifier: notifier,
        );

        await _emitWindowClose(tester, ctx.windowManager);
        expect(find.text('退出应用？'), findsOneWidget);

        // Second close event while the dialog is open → ignored.
        await _emitWindowClose(tester, ctx.windowManager);
        expect(find.text('退出应用？'), findsOneWidget);

        // Confirming still quits exactly once.
        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();
        expect(
          ctx.windowCalls.where((c) => c.method == 'destroy'),
          hasLength(1),
        );
        expect(ctx.exitCodes, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _resetDesktopAppServiceForTest();
      }
    });

    testWidgets(
      'tray rollback close cancellation keeps a running task and app alive',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          final notifier = BackgroundTaskNotifier();
          notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
          final ctx = await _pumpApplication(
            tester,
            closeMinimizes: false,
            taskNotifier: notifier,
            failTraySetup: true,
            failRollbackClear: true,
          );

          await _emitWindowClose(tester, ctx.windowManager);

          expect(find.text('退出应用？'), findsOneWidget);
          expect(find.textContaining('1 个任务正在运行'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(ctx.windowCalls.where((c) => c.method == 'destroy'), isEmpty);
          expect(ctx.exitCodes, isEmpty);

          // A later close can still confirm that cancellation left the active
          // task running, then explicitly approve the fallback exit.
          await _emitWindowClose(tester, ctx.windowManager);
          expect(find.text('退出应用？'), findsOneWidget);
          expect(find.textContaining('1 个任务正在运行'), findsOneWidget);
          await tester.tap(find.text('退出'));
          await tester.pumpAndSettle();
          expect(
            ctx.windowCalls.where((c) => c.method == 'destroy'),
            hasLength(1),
          );
          expect(ctx.exitCodes, [0]);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          _resetDesktopAppServiceForTest();
        }
      },
    );
  });
}
