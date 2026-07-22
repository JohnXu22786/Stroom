import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:stroom/pages/background_optimization_page.dart';
import 'package:stroom/services/background_service.dart';

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
  final mock = MockBackgroundServicePlatform();
  FlutterBackgroundServicePlatform.instance = mock;
  return mock;
}

void main() {
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
}
