import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/background_optimization_page.dart';

/// Builds the test app wrapping BackgroundOptimizationPage.
Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
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

/// Registers a mock background service platform for testing.
/// Returns the mock so tests can control its behavior.
MockBackgroundServicePlatform registerMockPlatform() {
  SharedPreferences.setMockInitialValues({});
  // Set up a mock MethodChannel handler for the keep-alive channel
  // so that fire-and-forget invokeMethod calls don't create pending
  // platform channel calls that fail the test after completion.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.johntsui.stroom/keepalive'),
    (MethodCall methodCall) async => true,
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
    // 清理跨测试泄漏的 mock 通道处理器。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
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

      // UI should still be intact with error status
      expect(find.text('无法检测后台服务状态'), findsOneWidget);
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
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'toggling desktop close-minimize off persists the pref and releases the close interception',
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

        // The desktop card has exactly one SwitchListTile.
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();

        // The preference is persisted...
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('desktop_close_minimize'), isFalse);
        // ...and the native close interception is released (argument
        // must be false), so the window closes normally instead of
        // minimizing.
        final preventCloseCalls =
            windowCalls.where((c) => c.method == 'setPreventClose').toList();
        expect(preventCloseCalls, isNotEmpty);
        expect(preventCloseCalls.last.arguments, {'isPreventClose': false});
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
  });
}
