import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/background_optimization_page.dart';
import 'package:stroom/services/desktop_app_service.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/services/ios_continued_task_service.dart';

/// Builds the test app wrapping BackgroundOptimizationPage.
/// Optionally overrides [backgroundTasksProvider] with a pre-seeded notifier
/// (e.g. to simulate running tasks for the quit-confirmation flow).
Widget _buildTestApp({BackgroundTaskNotifier? taskNotifier}) {
  return ProviderScope(
    overrides: taskNotifier == null
        ? []
        : [backgroundTasksProvider.overrideWith((ref) => taskNotifier)],
    child: const MaterialApp(
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

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async {
    return _configureResult;
  }

  @override
  Future<bool> start() async {
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

/// Records method calls made on the keep-alive method channel.
final List<MethodCall> keepAliveCalls = [];

/// Registers a mock background service platform for testing.
/// Returns the mock so tests can control its behavior.
MockBackgroundServicePlatform registerMockPlatform() {
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
  tearDown(() {
    // 清理跨测试泄漏的 mock 通道处理器与平台覆盖。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
    IosContinuedTaskService.debugForceSupported = false;
  });
  group('BackgroundOptimizationPage - rendering', () {
    testWidgets('renders page title', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Title bar
      expect(find.text('后台运行优化'), findsOneWidget);
    });

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

    testWidgets('shows background optimization status section', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 后台优化检测 should be visible
      expect(find.text('后台优化检测'), findsOneWidget);
    });

    testWidgets('shows platform tutorial categories', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 平台教程 should be visible
      expect(find.text('平台教程'), findsOneWidget);

      // Should show all platform tutorial cards
      expect(find.text('Android'), findsAtLeast(1));
      expect(find.text('iOS'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Linux'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - navigation', () {
    testWidgets(
        'tapping Android tutorial card navigates to PlatformTutorialPage', (
      tester,
    ) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the Android tutorial card by its unique subtitle
      await tester.tap(find.text('Android 后台运行优化教程'));
      await tester.pumpAndSettle();

      // Should navigate to PlatformTutorialPage with Android tutorial
      expect(find.text('Android 后台运行教程'), findsOneWidget);
    });

    testWidgets(
        'tapping Windows tutorial card navigates to PlatformTutorialPage', (
      tester,
    ) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Windows 后台运行优化教程'));
      await tester.pumpAndSettle();

      // Should navigate to PlatformTutorialPage with Windows tutorial
      expect(find.text('Windows 后台运行教程'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - service controls', () {
    testWidgets('shows loading indicator while checking service',
        (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      // Don't pump — the first pump triggers _checkBackgroundService
      // which is async. Before it completes, we should see loading.

      // The page starts checking on initState, so loading indicator should appear
      expect(find.text('正在检测...'), findsOneWidget);
    });

    testWidgets('shows start service button when service is not running',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show "启动服务" (Start Service) button
      expect(find.text('启动服务'), findsOneWidget);
      // Should show "重新检测" (Re-detect) button
      expect(find.text('重新检测'), findsOneWidget);
      // Should NOT show "停止服务" (Stop Service) button
      expect(find.text('停止服务'), findsNothing);
    });

    testWidgets('shows stop service button when service is running',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show "停止服务" (Stop Service) button
      expect(find.text('停止服务'), findsOneWidget);
      // Should show "重新检测" (Re-detect) button
      expect(find.text('重新检测'), findsOneWidget);
      // Should NOT show "启动服务" (Start Service) button
      expect(find.text('启动服务'), findsNothing);
    });

    testWidgets(
        'tapping start service button starts service and updates status',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Service is not running initially
      expect(find.text('启动服务'), findsOneWidget);

      // Tap start service button
      await tester.tap(find.text('启动服务'));
      await tester.pumpAndSettle();

      // After starting, service should be running — "停止服务" button should appear
      expect(find.text('停止服务'), findsOneWidget);
      expect(find.text('启动服务'), findsNothing);
    });

    testWidgets('tapping stop service button stops service and updates status',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Service is running initially
      expect(find.text('停止服务'), findsOneWidget);

      // Tap stop service button
      await tester.tap(find.text('停止服务'));
      await tester.pumpAndSettle();

      // After stopping, service should be stopped — "启动服务" button should appear
      expect(find.text('启动服务'), findsOneWidget);
      expect(find.text('停止服务'), findsNothing);
    });

    testWidgets('tapping re-detect button re-checks service status',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Service not running — start button visible
      expect(find.text('启动服务'), findsOneWidget);

      // Change mock to indicate service is now running
      mock.setServiceRunning(true);

      // Tap re-detect
      await tester.tap(find.text('重新检测'));
      await tester.pumpAndSettle();

      // After re-detect, service status should be updated — stop button visible
      expect(find.text('停止服务'), findsOneWidget);
      expect(find.text('启动服务'), findsNothing);
    });

    testWidgets('shows restart service button when service is running',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show "重新启动服务" button
      expect(find.text('重新启动服务'), findsOneWidget);
    });

    testWidgets('tapping restart service button restarts service',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);
      mock.setStartResult(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Service running — should see restart button
      expect(find.text('重新启动服务'), findsOneWidget);

      // Tap restart
      await tester.tap(find.text('重新启动服务'));
      await tester.pumpAndSettle();

      // After restart, service should still be running
      expect(find.text('停止服务'), findsOneWidget);
      expect(find.text('重新启动服务'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - error handling', () {
    testWidgets('handles service check error gracefully', (tester) async {
      final mock = registerMockPlatform();
      mock.setThrowOnCheck(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show error status
      expect(find.text('无法检测后台服务状态'), findsOneWidget);
      // Should still show re-detect button
      expect(find.text('重新检测'), findsOneWidget);
      // Should show start button since service is not running
      expect(find.text('启动服务'), findsOneWidget);
    });

    testWidgets('start service handles platform error gracefully',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setThrowOnCheck(true);
      mock.setThrowOnStart(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show error status initially
      expect(find.text('无法检测后台服务状态'), findsOneWidget);

      // Tap start — should not crash
      await tester.tap(find.text('启动服务'));
      await tester.pumpAndSettle();

      // startBackgroundService 内部捕获异常并返回 false，
      // 页面应显示真实的失败状态（而非静默忽略）。
      expect(find.text('启动服务失败'), findsOneWidget);
      // UI should still be intact
      expect(find.text('启动服务'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - service status display', () {
    testWidgets('shows running status when service is running', (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show running status
      expect(find.text('后台服务运行中'), findsOneWidget);
    });

    testWidgets('shows not running status when service is not running',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show not running status
      expect(find.text('后台服务未启动'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - platform specific messaging', () {
    /// Puts the desktop tray service into the ready state so the page
    /// renders the tray-resident copy (matching a real desktop session).
    Future<void> makeTrayReady() async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => true,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('tray_manager'),
        (MethodCall call) async => true,
      );
      await DesktopAppService.instance.setupTrayAndCloseBehavior();
    }

    testWidgets('desktop platforms explain tray-resident close behavior',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await makeTrayReady();

        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // The desktop description must mention the tray-resident behavior
        // (also present in the close-minimize toggle's detail text).
        expect(find.textContaining('系统托盘'), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopAppService.instance.resetForTesting();
      }
    });

    testWidgets('linux explains restore via the tray menu', (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await makeTrayReady();

        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // On Linux, restore happens via the tray menu, not icon click.
        expect(find.textContaining('托盘菜单选择「显示主窗口」'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopAppService.instance.resetForTesting();
      }
    });

    testWidgets('desktop platforms warn honestly when tray is unavailable',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        // No tray setup performed — the service is not tray-ready.
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 状态行与描述卡片都会如实说明托盘不可用（不再显示
        // 「使用托盘驻留保活」的误导性文案）。
        expect(find.textContaining('托盘暂不可用'), findsWidgets);
        expect(find.textContaining('使用托盘驻留保活'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('android shows battery optimization card', (tester) async {
      registerMockPlatform();

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Default test platform is Android — the battery card must render its
      // status row (mock reports the app already ignores battery optimization).
      expect(find.text('已忽略电池优化'), findsOneWidget);
    });

    testWidgets('android shows exact-alarm button when permission is missing',
        (tester) async {
      registerMockPlatform();
      // Mock reports exact alarms are NOT permitted (Android 14+ default).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall methodCall) async =>
            methodCall.method == 'canScheduleExactAlarms' ? false : true,
      );

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('允许精确闹钟（保活更可靠）'), findsOneWidget);
    });

    testWidgets('exact-alarm status is re-checked when the app resumes',
        (tester) async {
      // 回归：精确闹钟权限只可能在系统设置中变更（撤销时系统不发
      // 广播），回到前台必须重新检测，否则按钮状态永远是旧的。
      var exactAlarmsAllowed = false;
      registerMockPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall methodCall) async =>
            methodCall.method == 'canScheduleExactAlarms'
                ? exactAlarmsAllowed
                : true,
      );

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // 初始：权限缺失 → 显示授权按钮。
      expect(find.text('允许精确闹钟（保活更可靠）'), findsOneWidget);

      // 用户在系统设置中授予权限 → 回到前台 → 按钮必须消失。
      exactAlarmsAllowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('允许精确闹钟（保活更可靠）'), findsNothing,
          reason: 'resume 后必须重新检测精确闹钟权限');
    });
  });

  group('BackgroundOptimizationPage - keep-alive strategy toggles (watchdog)',
      () {
    testWidgets('turning the watchdog off disarms the native alarm',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('AlarmManager 看门狗'));
      await tester.pumpAndSettle();

      expect(
        keepAliveCalls.any((c) => c.method == 'stopKeepAlive'),
        isTrue,
        reason:
            'disabling the watchdog must cancel the native keep-alive alarm',
      );
    });

    testWidgets('turning the watchdog on while running arms the alarm',
        (tester) async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      // Watchdog starts disabled so the toggle can be turned on.
      SharedPreferences.setMockInitialValues({
        'background_service_watchdog': false,
      });

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('AlarmManager 看门狗'));
      await tester.pumpAndSettle();

      expect(
        keepAliveCalls.any((c) => c.method == 'startKeepAlive'),
        isTrue,
        reason: 're-enabling the watchdog while the service runs must arm '
            'the native keep-alive alarm',
      );
    });
  });
  group('BackgroundOptimizationPage - keep-alive strategy toggles', () {
    testWidgets('Android shows all three strategy toggles', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('AlarmManager 看门狗'), findsOneWidget);
      expect(find.text('冷启动自动恢复'), findsOneWidget);
      expect(find.text('电池优化提醒'), findsOneWidget);
      // Desktop-only card must NOT be shown on Android
      expect(find.text('关闭窗口时最小化'), findsNothing);
    });

    testWidgets(
        'toggling watchdog off persists the pref and disables the alarm',
        (tester) async {
      registerMockPlatform();
      // Record keep-alive channel calls.
      final keepAliveCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall call) async {
          keepAliveCalls.add(call.method);
          return true;
        },
      );

      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the watchdog switch (SwitchListTile) to turn it off.
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('background_service_watchdog'), isFalse);
      expect(keepAliveCalls, contains('stopKeepAlive'));
    });

    testWidgets('disabling battery reminder hides the battery card',
        (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Battery card is initially visible (Android + reminder enabled).
      expect(find.text('已忽略电池优化'), findsOneWidget);

      // The battery reminder toggle is the last SwitchListTile.
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();

      // Battery card disappears after the reminder is disabled.
      expect(find.text('已忽略电池优化'), findsNothing);
    });

    testWidgets('iOS shows only the cold-start toggle', (tester) async {
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

        expect(find.text('冷启动自动恢复'), findsOneWidget);
        // Android-only toggles must not appear on iOS
        expect(find.text('AlarmManager 看门狗'), findsNothing);
        expect(find.text('电池优化提醒'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('desktop shows close-minimize card instead of mobile toggles',
        (tester) async {
      registerMockPlatform();
      // Mock the window_manager channel so setPreventClose etc. work.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => true,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Desktop keep-alive card with minimize-on-close toggle + quit button
        expect(find.text('关闭窗口时最小化'), findsOneWidget);
        expect(find.text('完全退出应用'), findsOneWidget);
        // Mobile strategy toggles must not appear on desktop
        expect(find.text('AlarmManager 看门狗'), findsNothing);
        expect(find.text('冷启动自动恢复'), findsNothing);
        // iOS-only background note card must not appear on desktop
        expect(find.text('iOS 后台任务提示'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'toggling desktop close-minimize off persists the pref but keeps the close interception',
        (tester) async {
      registerMockPlatform();
      // Record window_manager channel calls (method + arguments).
      final windowCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          windowCalls.add(call);
          return true;
        },
      );
      // 托盘通道同样 mock，并先完成托盘注册 —— 页面只会在托盘就绪后
      // 才重新武装关闭拦截（托盘不可用时不武装，保证窗口仍可关闭）。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('tray_manager'),
        (MethodCall call) async => true,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        expect(DesktopAppService.instance.isTrayReady, isTrue);

        tester.view.physicalSize = const Size(1080, 5000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // The desktop card has exactly one SwitchListTile.
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();

        // The preference is persisted...
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('desktop_close_minimize'), isFalse);
        // ...but the close interception must NEVER be released:
        // releasing it would let the native layer destroy the window
        // before the quit confirmation can run.
        final preventCloseCalls =
            windowCalls.where((c) => c.method == 'setPreventClose').toList();
        expect(preventCloseCalls, isNotEmpty);
        expect(
          preventCloseCalls.every(
            (c) => (c.arguments as Map)['isPreventClose'] == true,
          ),
          isTrue,
          reason: 'setPreventClose(false) 会释放拦截，导致退出确认失效',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopAppService.instance.resetForTesting();
      }
    });

    testWidgets(
        'does not re-arm close interception when the tray is unavailable',
        (tester) async {
      // 托盘注册失败（未 mock tray 通道）→ DesktopAppService 已回滚为
      // 「关闭即退出」。页面此时绝不能只恢复 setPreventClose 而不恢复
      // 事件监听 —— 否则窗口将无法关闭。
      registerMockPlatform();
      final windowCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          windowCalls.add(call);
          return true;
        },
      );
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
    });

    testWidgets('re-checks service status when app resumes from background',
        (tester) async {
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

    testWidgets('quit button exits directly when no tasks are running',
        (tester) async {
      registerMockPlatform();
      // Record window_manager channel calls.
      final windowCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          windowCalls.add(call);
          return true;
        },
      );
      // Record the process exit instead of actually exiting.
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      try {
        DesktopAppService.instance.resetForTesting();
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
        DesktopAppService.instance.resetForTesting();
      }
    });
    testWidgets('quit button respects the injected quit confirmation',
        (tester) async {
      registerMockPlatform();
      final windowCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async {
          windowCalls.add(call);
          return true;
        },
      );
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      try {
        DesktopAppService.instance.resetForTesting();
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
        DesktopAppService.instance.resetForTesting();
      }
    });
  });

  group('BackgroundOptimizationPage - iOS background note card', () {
    testWidgets('iOS shows the background note card with old-iOS tips',
        (tester) async {
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

    testWidgets('iOS 26 shows the resident-background supported message',
        (tester) async {
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
    testWidgets('tutorial card list includes a Web entry', (tester) async {
      registerMockPlatform();
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // 六个平台教程入口都可达（Android 同时出现在平台检测卡，
      // 因此用 findsWidgets；'Web' 只在教程卡片出现，可精确断言）。
      expect(find.text('Android'), findsWidgets);
      expect(find.text('iOS'), findsWidgets);
      expect(find.text('Windows'), findsWidgets);
      expect(find.text('macOS'), findsWidgets);
      expect(find.text('Linux'), findsWidgets);
      expect(find.text('Web'), findsOneWidget);
    });
  });
}
