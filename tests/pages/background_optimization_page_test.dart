Warning: truncated output (original token count: 17689)
Total output lines: 1970

import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/background_optimization_page.dart';
import 'package:stroom/services/background_service.dart';
import 'package:stroom/services/desktop_app_service.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/services/ios_continued_task_service.dart';
import 'package:tray_manager/legacy.dart' show Menu, TrayListener;

class _TestDesktopTrayAdapter implements DesktopTrayAdapter {
  _TestDesktopTrayAdapter({this.onSetContextMenu});

  final Future<void> Function(Menu menu)? onSetContextMenu;

  @override
  Future<void> setIcon(String iconPath) async {}

  @override
  Future<void> setToolTip(String toolTip) async {}

  @override
  Future<void> setContextMenu(Menu menu) async => onSetContextMenu?.call(menu);

  @override
  Future<void> popUpContextMenu() async {}

  @override
  Future<void> destroy() async {}

  @override
  void addListener(TrayListener listener) {}

  @override
  void removeListener(TrayListener listener) {}
}

class _TestDesktopWindowManagerAdapter implements DesktopWindowManagerAdapter {
  final calls = <MethodCall>[];
  final listeners = <DesktopWindowListener>[];

  void reset() {
    calls.clear();
    listeners.clear();
  }

  void _record(String method, [Object? arguments]) {
    calls.add(MethodCall(method, arguments));
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
  void addListener(DesktopWindowListener listener) {
    listeners.add(listener);
    _record('addListener');
  }

  @override
  void removeListener(DesktopWindowListener listener) {
    listeners.remove(listener);
    _record('removeListener');
  }
}

final _testDesktopWindowManagerAdapter = _TestDesktopWindowManagerAdapter();

void _resetDesktopAppServiceForTest() {
  final service = DesktopAppService.instance;
  service.resetForTesting();
  _testDesktopWindowManagerAdapter.reset();
  service.setWindowManagerAdapterForTesting(_testDesktopWindowManagerAdapter);
  service.setTrayAdapterForTesting(_TestDesktopTrayAdapter());
}

/// Builds the test app wrapping BackgroundOptimizationPage.
/// Optionally overrides [backgroundTasksProvider] with a pre-seeded notifier
/// (e.g. to simulate running tasks for the quit-confirmation flow).
Widget _buildTestApp({
  BackgroundTaskNotifier? taskNotifier,
  Locale locale = const Locale('zh', 'CN'),
}) {
  return ProviderScope(
    overrides: taskNotifier == null
        ? []
        : [backgroundTasksProvider.overrideWith((ref) => taskNotifier)],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BackgroundOptimizationPage(),
    ),
  );
}

/// A mock implementation of FlutterBackgroundServicePlatform for testing.
class MockBackgroundServicePlatform extends FlutterBackgroundServicePlatform {
  bool _isRunning = false;
  bool _configureResult = true;
  bool _startResult = true;
  bool _throwOnStart = false;
  bool _throwOnCheck = false;
  Completer<bool>? _serviceStatusCompleter;
  int startCallCount = 0;

  void setServiceRunning(bool running) {
    _isRunning = running;
  }

  void setConfigureResult(bool result) {
    _configureResult = result;
  }

  void setStartResult(bool result) {
    _startResult = result;
  }

  void setThrowOnStart(bool shouldThrow) {
    _throwOnStart = shouldThrow;
  }

  void setThrowOnCheck(bool shouldThrow) {
    _throwOnCheck = shouldThrow;
  }

  void setServiceStatusCompleter(Completer<bool> completer) {
    _serviceStatusCompleter = completer;
  }

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async {
    return _configureResult;
  }

  @override
  Future<bool> start() async {
    startCallCount++;
    if (_throwOnStart) {
      throw 'Simulated start error';
    }
    _isRunning = _startResult;
    return _startResult;
  }

  @override
  Future<bool> isServiceRunning() async {
    if (_throwOnCheck) {
      throw 'Simulated check error';
    }
    final serviceStatusCompleter = _serviceStatusCompleter;
    if (serviceStatusCompleter != null) {
      return serviceStatusCompleter.future;
    }
    return _isRunning;
  }

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    if (method == 'stopService') {
      _isRunning = false;
    }
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    return const Stream.empty();
  }
}

class _FailingDesktopCloseMinimizePreferenceStore
    extends InMemorySharedPreferencesStore {
  _FailingDesktopCloseMinimizePreferenceStore(Map<String, Object> data)
      : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'Bool' && key == 'flutter.desktop_close_minimize') {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _FailingRecoveryPreferenceStore extends InMemorySharedPreferencesStore {
  _FailingRecoveryPreferenceStore(
    Map<String, Object> data, {
    required Set<String> failedKeys,
  })  : _failedKeys = failedKeys,
        super.withData(data);

  final Set<String> _failedKeys;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'Bool' && _failedKeys.contains(key)) {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

Future<SharedPreferencesStorePlatform> _failRecoveryPreferenceWrites(
  SharedPreferences preferences, {
  required Map<String, Object> data,
  required Set<String> failedKeys,
}) async {
  final originalStore = SharedPreferencesStorePlatform.instance;
  SharedPreferencesStorePlatform.instance = _FailingRecoveryPreferenceStore(
    data,
    failedKeys: failedKeys,
  );
  await preferences.reload();
  return originalStore;
}

/// Records method calls made on the keep-alive method channel.
final List<MethodCall> keepAliveCalls = [];

/// Registers a mock background service platform for testing.
/// Returns the mock so tests can control its behavior.
MockBackgroundServicePlatform registerMockPlatform() {
  resetBackgroundServiceLifecycleStateForTesting();
  keepAliveCalls.clear();
  SharedPreferences.setMockInitialValues({});
  // Set up a mock MethodChannel handler for the keep-alive channel
  // so that fire-and-forget invokeMethod calls don't create pending
  // platform channel calls that fail the test after completion.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.johntsui.stroom/keepalive'),
    (MethodCall methodCall) async {
      keepAliveCalls.add(methodCall);
      return true;
    },
  );
  // Mock the notification permission channel: without a handler the
  // status check future never completes in widget tests, forcing the
  // production 8s timeout to elapse in fake time for every start flow.
  // statusByValue(1) == PermissionStatus.granted.
  // Permission.notification has index 17 in permission_handler.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (MethodCall call) async {
      if (call.method == 'checkPermissionStatus') return 1;
      if (call.method == 'requestPermissions') {
        return <int, int>{17: 1}; // notification permission -> granted
      }
      return true;
    },
  );
  final mock = MockBackgroundServicePlatform();
  FlutterBackgroundServicePlatform.instance = mock;
  return mock;
}

void main() {
  testWidgets('background optimization title follows the selected locale', (
    tester,
  ) async {
    registerMockPlatform();
    await tester.pumpWidget(_buildTestApp(locale: const Locale('en', 'US')));
    await tester.pumpAndSettle();
    expect(find.text('Background Optimization'), findsOneWidget);
  });

  setUp(_resetDesktopAppServiceForTest);

  tearDown(() {
    // 清理跨测试泄漏的 mock 通道处理器与平台覆盖。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.johntsui.stroom/keepalive'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
    IosContinuedTaskService.debugForceSupported = false;
  });
  group('BackgroundOptimizationPage - rendering', () {
    testWidgets('shows system environment detection section', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 系统环境检测 should be visible
      expect(find.text('系统环境检测'), findsOneWidget);
      // Platform name should be displayed (Android in test env)
      expect(find.text('Android'), findsAtLeast(1));
    });
  });

  group('BackgroundOptimizationPage - navigation', () {
    testWidgets(
      'tapping Android tutorial card navigates to PlatformTutorialPage',
      (tester) async {
        registerMockPlatform();
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pump();

        await tester.tap(find.text('查看各个平台的后台运行优化教程'));
        await tester.pumpAndSettle();
        expect(find.text('平台教程'), findsOneWidget);
        expect(find.text('Android 后台运行优化教程'), findsOneWidget);

        await tester.tap(find.text('Android 后台运行优化教程'));
        await tester.pumpAndSettle();
        expect(find.text('Android 后台运行教程'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Windows tutorial card navigates to PlatformTutorialPage',
      (tester) async {
        registerMockPlatform();
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pump();…11689 tokens truncated…topAppServiceForTest();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final originalExitApp = DesktopAppService.exitApp;
        final exitCodes = <int>[];
        DesktopAppService.exitApp = exitCodes.add;
        try {
          final prefs = await SharedPreferences.getInstance();
          final originalStore = SharedPreferencesStorePlatform.instance;
          SharedPreferencesStorePlatform.instance =
              _FailingDesktopCloseMinimizePreferenceStore({
            'flutter.desktop_close_minimize': true,
          });
          await prefs.reload();
          addTearDown(() {
            SharedPreferencesStorePlatform.instance = originalStore;
          });

          tester.view.physicalSize = const Size(1080, 5000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final windowCalls = _testDesktopWindowManagerAdapter.calls;
          await DesktopAppService.instance.setupTrayAndCloseBehavior();
          expect(DesktopAppService.instance.isTrayReady, isTrue);

          await tester.pumpWidget(_buildTestApp());
          await tester.pumpAndSettle();

          final toggle = find.byType(SwitchListTile).first;
          expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
          await tester.tap(toggle);
          await tester.pumpAndSettle();

          expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

          // A close must use the same live SharedPreferences cache as the
          // failed write; reloading here would mask a stale cached false value.
          DesktopAppService.instance.onWindowClose();
          await tester.pump(const Duration(milliseconds: 20));

          expect(
            windowCalls.where((call) => call.method == 'hide'),
            hasLength(1),
          );
          expect(
            windowCalls.where((call) => call.method == 'destroy'),
            isEmpty,
          );
          expect(exitCodes, isEmpty);
          expect(prefs.getBool('desktop_close_minimize'), isTrue);
        } finally {
          DesktopAppService.exitApp = originalExitApp;
          debugDefaultTargetPlatformOverride = null;
          _resetDesktopAppServiceForTest();
        }
      },
    );

    testWidgets(
      'does not re-arm close interception when the tray is unavailable',
      (tester) async {
        // 托盘注册失败（未 mock tray 通道）→ DesktopAppService 已回滚为
        // 「关闭即退出」。页面此时绝不能只恢复 setPreventClose 而不恢复
        // 事件监听 —— 否则窗口将无法关闭。
        registerMockPlatform();
        final windowCalls = _testDesktopWindowManagerAdapter.calls;
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          expect(DesktopAppService.instance.isTrayReady, isFalse);

          tester.view.physicalSize = const Size(1080, 5000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(_buildTestApp());
          await tester.pumpAndSettle();

          await tester.tap(find.byType(SwitchListTile).first);
          await tester.pumpAndSettle();

          // 页面加载与切换开关都不应武装关闭拦截。
          final preventCloseCalls =
              windowCalls.where((c) => c.method == 'setPreventClose').toList();
          expect(preventCloseCalls, isEmpty, reason: '托盘不可用时重新武装拦截会制造无法关闭的窗口');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('re-checks service status when app resumes from background', (
      tester,
    ) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('后台服务未启动'), findsOneWidget);

      // The service was started elsewhere while the app was in background.
      mock.setServiceRunning(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('后台服务运行中'), findsOneWidget);
    });

    testWidgets('quit button exits directly when no tasks are running', (
      tester,
    ) async {
      registerMockPlatform();
      // Record calls through the injected window-manager adapter.
      final windowCalls = _testDesktopWindowManagerAdapter.calls;
      // Record the process exit instead of actually exiting.
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      try {
        _resetDesktopAppServiceForTest();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // No quit-confirmation callback injected — quit proceeds directly.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('完全退出应用'));
        await tester.pumpAndSettle();

        // Quits immediately without a confirmation dialog,
        // destroying the window and exiting the process.
        expect(find.text('退出应用？'), findsNothing);
        expect(windowCalls.where((c) => c.method == 'destroy'), hasLength(1));
        expect(exitCodes, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopAppService.exitApp = exit;
        _resetDesktopAppServiceForTest();
      }
    });
    testWidgets('quit button respects the injected quit confirmation', (
      tester,
    ) async {
      registerMockPlatform();
      final windowCalls = _testDesktopWindowManagerAdapter.calls;
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      try {
        _resetDesktopAppServiceForTest();
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // User cancels the confirmation -> nothing is destroyed, no exit.
        DesktopAppService.instance.onQuitConfirmation = () async => false;
        await tester.tap(find.text('完全退出应用'));
        await tester.pumpAndSettle();
        expect(windowCalls.where((c) => c.method == 'destroy'), isEmpty);
        expect(exitCodes, isEmpty);

        // User confirms -> window destroyed and process exits.
        DesktopAppService.instance.onQuitConfirmation = () async => true;
        await tester.tap(find.text('完全退出应用'));
        await tester.pumpAndSettle();
        expect(windowCalls.where((c) => c.method == 'destroy'), hasLength(1));
        expect(exitCodes, [0]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopAppService.exitApp = exit;
        DesktopAppService.instance.onQuitConfirmation = null;
        _resetDesktopAppServiceForTest();
      }
    });
  });

  group('BackgroundOptimizationPage - iOS background note card', () {
    testWidgets('iOS shows the background note card with old-iOS tips', (
      tester,
    ) async {
      registerMockPlatform();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 卡片与「低于 iOS 26」提示（测试机非 iOS 26，isSupported=false）。
        expect(find.text('iOS 后台任务提示'), findsOneWidget);
        expect(find.textContaining('低于 iOS 26'), findsOneWidget);
        expect(find.textContaining('每隔几分钟返回一次'), findsOneWidget);
        // 通用警示：勿在 App 切换器中划掉。
        expect(find.textContaining('请勿在 App 切换器中划掉'), findsOneWidget);
        // 桌面端卡片不显示。
        expect(find.text('关闭窗口时最小化'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS 26 shows the resident-background supported message', (
      tester,
    ) async {
      registerMockPlatform();
      IosContinuedTaskService.debugForceSupported = true;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('iOS 后台任务提示'), findsOneWidget);
        expect(find.textContaining('支持任务常驻后台'), findsOneWidget);
        expect(find.textContaining('低于 iOS 26'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('BackgroundOptimizationPage - platform tutorial cards', () {
    testWidgets('tutorial entry is below system environment detection', (
      tester,
    ) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final detectionCard = find
          .ancestor(of: find.text('Android'), matching: find.byType(Card))
          .first;
      final tutorialCard = find.ancestor(
        of: find.text('查看各个平台的后台运行优化教程'),
        matching: find.byType(Card),
      );
      expect(
        tester.getTopLeft(tutorialCard).dy,
        greaterThan(tester.getBottomLeft(detectionCard).dy),
      );
      expect(find.text('Android 后台运行优化教程'), findsNothing);
    });

    testWidgets('platform tutorial page lists supported platforms', (
      tester,
    ) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看各个平台的后台运行优化教程'));
      await tester.pumpAndSettle();

      expect(find.text('Android 后台运行优化教程'), findsOneWidget);
      expect(find.text('iOS 后台运行优化教程'), findsOneWidget);
      expect(find.text('Windows 后台运行优化教程'), findsOneWidget);
      expect(find.text('macOS 后台运行优化教程'), findsOneWidget);
      expect(find.text('Linux 后台运行优化教程'), findsOneWidget);
      expect(find.text('Web 后台运行优化教程'), findsOneWidget);
    });
  });
}
