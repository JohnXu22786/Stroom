import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/application.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/update_provider.dart';
import 'package:stroom/providers/theme_provider.dart';

/// Mock [Dio] that resolves every request with the given response
/// (same version as the app → no update dialog during startup).
Dio _createMockDio() {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: jsonDecode(
          '[{"tag_name": "v0.4.47", "published_at": "2024-01-15T10:00:00Z",'
          ' "body": "", "html_url": "https://github.com/JohnXu22786/Stroom"}]',
        ),
      ));
    },
  ));
  return dio;
}

/// Pumps the full [Application] (like the real app root) with the
/// window-manager channel mocked and the platform forced to Windows.
Future<({List<MethodCall> windowCalls, BackgroundTaskNotifier notifier})>
    _pumpApplication(
  WidgetTester tester, {
  required bool closeMinimizes,
  BackgroundTaskNotifier? taskNotifier,
}) async {
  SharedPreferences.setMockInitialValues({
    'data_format_version': 2, // skip migration
    'desktop_close_minimize': closeMinimizes,
  });

  final windowCalls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (MethodCall call) async {
      windowCalls.add(call);
      return true;
    },
  );

  final notifier = taskNotifier ?? BackgroundTaskNotifier();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeProvider.overrideWith((ref) => ThemeNotifier()),
      updateProvider
          .overrideWith((ref) => UpdateNotifier(dio: _createMockDio())),
      backgroundTasksProvider.overrideWith((ref) => notifier),
    ],
    child: const Application(),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();

  return (windowCalls: windowCalls, notifier: notifier);
}

/// Simulates the native window close event arriving on the
/// window_manager method channel (eventName: 'close').
Future<void> _emitWindowClose(WidgetTester tester) async {
  const codec = StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'window_manager',
    codec.encodeMethodCall(
      const MethodCall('onEvent', {'eventName': 'close'}),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 平台覆盖必须在测试体内 try/finally 重置
  // （_verifyInvariants 在 tearDown 之前运行）。
  void useWindowsPlatform() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  }

  group('Application - close-to-quit confirmation', () {
    testWidgets('close in minimize mode minimizes without confirmation',
        (tester) async {
      useWindowsPlatform();
      try {
        final ctx = await _pumpApplication(tester, closeMinimizes: true);

        await _emitWindowClose(tester);

        expect(find.text('退出应用？'), findsNothing);
        expect(
            ctx.windowCalls.where((c) => c.method == 'minimize'), hasLength(1));
        expect(ctx.windowCalls.where((c) => c.method == 'destroy'), isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('close in quit mode with no tasks quits directly',
        (tester) async {
      useWindowsPlatform();
      try {
        final ctx = await _pumpApplication(tester, closeMinimizes: false);

        await _emitWindowClose(tester);

        expect(find.text('退出应用？'), findsNothing);
        expect(
            ctx.windowCalls.where((c) => c.method == 'destroy'), hasLength(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'close in quit mode with running tasks asks for confirmation '
        'and cancelling keeps the window open', (tester) async {
      useWindowsPlatform();
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(tester,
            closeMinimizes: false, taskNotifier: notifier);

        await _emitWindowClose(tester);

        // Confirmation dialog appears; cancel keeps the window open.
        expect(find.text('退出应用？'), findsOneWidget);
        expect(find.textContaining('1 个任务正在运行'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(ctx.windowCalls.where((c) => c.method == 'destroy'), isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('close in quit mode with running tasks quits after confirm',
        (tester) async {
      useWindowsPlatform();
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(tester,
            closeMinimizes: false, taskNotifier: notifier);

        await _emitWindowClose(tester);

        expect(find.text('退出应用？'), findsOneWidget);
        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();
        expect(
            ctx.windowCalls.where((c) => c.method == 'destroy'), hasLength(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'repeated close events while the dialog is open do not stack '
        'a second dialog', (tester) async {
      useWindowsPlatform();
      try {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.ocr, title: '运行中任务');
        final ctx = await _pumpApplication(tester,
            closeMinimizes: false, taskNotifier: notifier);

        await _emitWindowClose(tester);
        expect(find.text('退出应用？'), findsOneWidget);

        // Second close event while the dialog is open → ignored.
        await _emitWindowClose(tester);
        expect(find.text('退出应用？'), findsOneWidget);

        // Confirming still quits exactly once.
        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();
        expect(
            ctx.windowCalls.where((c) => c.method == 'destroy'), hasLength(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
