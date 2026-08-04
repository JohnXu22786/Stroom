import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/background_service.dart';

/// A mock implementation of FlutterBackgroundServicePlatform for testing
/// persistence behavior. Extends the real platform interface to control
/// service running state in tests.
class MockBackgroundServicePlatform extends FlutterBackgroundServicePlatform {
  bool _isRunning = false;
  bool _configureResult = true;
  bool _startResult = true;
  bool _throwOnStart = false;
  bool _throwOnCheck = false;

  /// The last AndroidConfiguration passed to [configure], captured so tests
  /// can assert the foreground service type wiring.
  AndroidConfiguration? lastAndroidConfiguration;

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
    lastAndroidConfiguration = androidConfiguration;
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

/// Registers a mock background service platform for testing and returns it.
MockBackgroundServicePlatform registerMockPlatform() {
  final mock = MockBackgroundServicePlatform();
  FlutterBackgroundServicePlatform.instance = mock;
  return mock;
}

/// Runs [body] with the Android platform override active.
Future<void> withAndroidPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    keepAliveCalls.clear();
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
  });

  group('BackgroundService - basic', () {
    test(
        'initializeBackgroundService handles errors gracefully in non-supported platforms',
        () async {
      // In test environment (not Android/iOS), the platform channel
      // will throw "FlutterBackgroundService is currently supported
      // for Android and iOS Platform only"
      // The function should handle this without crashing.
      await initializeBackgroundService();
      // Reaching here means no unhandled exception
      expect(true, isTrue);
    });

    test(
        'startBackgroundService handles errors gracefully when platform unavailable',
        () async {
      // Should not crash even if service is not available
      await startBackgroundService();
      expect(true, isTrue);
    });

    test(
        'stopBackgroundService handles errors gracefully when platform unavailable',
        () async {
      await stopBackgroundService();
      expect(true, isTrue);
    });

    test('onStart is a valid top-level function', () {
      expect(onStart, isA<Function>());
    });

    test('onIosBackground is a valid top-level function', () {
      expect(onIosBackground, isA<Function>());
    });

    test('notification channel configuration constants are valid', () {
      // These constants are used for Android notification channel
      const serviceName = 'com.johntsui.stroom.background_service';
      expect(serviceName, isNotEmpty);
      expect(serviceName, contains('stroom'));
    });
  });

  group('BackgroundService - cold start auto-restore', () {
    test(
        'restoreBackgroundServiceOnColdStart does not crash when platform unavailable',
        () async {
      // Should not crash even if the platform does not support background service
      await restoreBackgroundServiceOnColdStart();
      expect(true, isTrue);
    });

    test('startBackgroundService persists enabled state to SharedPreferences',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      await startBackgroundService();

      // Verify the enabled state was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('background_service_enabled'), isTrue);
    });

    test('stopBackgroundService clears enabled state from SharedPreferences',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      // First set the pref to true to simulate service was running
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await stopBackgroundService();

      // Verify the enabled state was cleared
      expect(prefs.getBool('background_service_enabled'), isFalse);
    });

    test(
        'restoreBackgroundServiceOnColdStart starts service when previously enabled',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      // Simulate that the service was previously running
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      // In test env, isBackgroundServiceSupported acts based on
      // defaultTargetPlatform. Override to Android to test the path.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await restoreBackgroundServiceOnColdStart();
        // Service should now be running (mock sets it via startResult)
        expect(mock._isRunning, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('restoreBackgroundServiceOnColdStart does nothing when pref is false',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      // Pref is false (not previously enabled)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', false);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await restoreBackgroundServiceOnColdStart();
        // Service should remain not running
        expect(mock._isRunning, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
        'restoreBackgroundServiceOnColdStart handles missing pref (treats as false)',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);

      // No background_service_enabled key set at all
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await restoreBackgroundServiceOnColdStart();
        // Service should remain not running (default false)
        expect(mock._isRunning, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
        'restoreBackgroundServiceOnColdStart does nothing when cold-start restore toggle is off',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      // Service was previously enabled...
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      // ...but the user disabled cold-start auto-restore.
      await setColdStartRestoreEnabled(false);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await restoreBackgroundServiceOnColdStart();
        // Service must NOT be started
        expect(mock._isRunning, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('BackgroundService - keep-alive strategy toggles', () {
    test('watchdog toggle defaults to enabled', () async {
      expect(await isWatchdogEnabled(), isTrue);
    });

    test('watchdog toggle persists its value', () async {
      await setWatchdogEnabled(false);
      expect(await isWatchdogEnabled(), isFalse);
      await setWatchdogEnabled(true);
      expect(await isWatchdogEnabled(), isTrue);
    });

    test('cold-start restore toggle defaults to enabled and persists',
        () async {
      expect(await isColdStartRestoreEnabled(), isTrue);
      await setColdStartRestoreEnabled(false);
      expect(await isColdStartRestoreEnabled(), isFalse);
    });

    test('battery reminder toggle defaults to enabled and persists', () async {
      expect(await isBatteryReminderEnabled(), isTrue);
      await setBatteryReminderEnabled(false);
      expect(await isBatteryReminderEnabled(), isFalse);
    });

    test('desktop close-minimize toggle defaults to enabled and persists',
        () async {
      expect(await isDesktopCloseMinimizeEnabled(), isTrue);
      await setDesktopCloseMinimizeEnabled(false);
      expect(await isDesktopCloseMinimizeEnabled(), isFalse);
    });

    test('isDesktopPlatform reflects the target platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(isDesktopPlatform(), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(isDesktopPlatform(), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('restartBackgroundService persists enabled state', () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);
      mock.setStartResult(true);

      // Simulate a previously persisted "disabled" state.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', false);

      await restartBackgroundService();

      // After restart the enabled state must be persisted again so a
      // later process death still triggers cold-start restore.
      expect(prefs.getBool('background_service_enabled'), isTrue);
    });
  });

  group('BackgroundService - keep-alive watchdog wiring', () {
    test('AndroidConfiguration declares the dataSync foreground service type',
        () async {
      final mock = registerMockPlatform();
      await initializeBackgroundService();
      final config = mock.lastAndroidConfiguration;
      expect(config, isNotNull);
      expect(config!.foregroundServiceTypes,
          contains(AndroidForegroundType.dataSync));
    });

    test('startBackgroundService arms the AlarmManager watchdog', () async {
      registerMockPlatform();
      await withAndroidPlatform(() async {
        await startBackgroundService();
      });
      expect(
        keepAliveCalls.any((c) => c.method == 'startKeepAlive'),
        isTrue,
        reason: 'starting the service must arm the native keep-alive alarm',
      );
    });

    test('stopBackgroundService disarms the AlarmManager watchdog', () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);
      await withAndroidPlatform(() async {
        await stopBackgroundService();
      });
      expect(
        keepAliveCalls.any((c) => c.method == 'stopKeepAlive'),
        isTrue,
        reason: 'stopping the service must cancel the native keep-alive alarm',
      );
    });

    test(
        'cold-start restore re-arms the watchdog alarm after restoring service',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await withAndroidPlatform(() async {
        await restoreBackgroundServiceOnColdStart();
      });

      expect(mock._isRunning, isTrue);
      expect(
        keepAliveCalls.any((c) => c.method == 'rearmKeepAlive'),
        isTrue,
        reason: 'restoring the service on cold start must also re-arm the '
            'watchdog alarm (the alarm does not survive force-stop or updates)',
      );
      expect(keepAliveCalls.any((c) => c.method == 'startKeepAlive'), isFalse,
          reason: '冷启动恢复是补武装场景，不得清零失败计数');
    });

    test('cold-start restore skips the watchdog when its toggle is disabled',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_watchdog', false);

      await withAndroidPlatform(() async {
        await restoreBackgroundServiceOnColdStart();
      });

      // Service itself is still restored, but no alarm may be armed.
      expect(mock._isRunning, isTrue);
      expect(
        keepAliveCalls.any((c) => c.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('startBackgroundService does not arm watchdog when toggle is disabled',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_watchdog', false);

      await withAndroidPlatform(() async {
        await startBackgroundService();
      });
      expect(
        keepAliveCalls.any((c) => c.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('keep-alive channel calls are never made on desktop platforms',
        () async {
      registerMockPlatform();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await startBackgroundService();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(keepAliveCalls, isEmpty);
    });

    test('rearmKeepAliveOnResume re-arms the watchdog when service enabled',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_cold_start_restore', true);

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(
        keepAliveCalls.any((c) => c.method == 'rearmKeepAlive'),
        isTrue,
        reason: 'returning to the app must re-arm the alarm — the system '
            'silently deletes exact alarms when the permission is revoked',
      );
      // 补武装不得清零失败计数（持久失败环境下看门狗应保持退避）。
      expect(keepAliveCalls.any((c) => c.method == 'startKeepAlive'), isFalse,
          reason: 'resume 是补武装场景，不得使用带计数清零的 startKeepAlive');
    });

    test('rearmKeepAliveOnResume respects the cold-start restore toggle',
        () async {
      // 回归：用户关闭「冷启动自动恢复」后，回到前台同样不得重新武装
      // 看门狗 —— 否则闹钟触发会复活一个用户已明确不要求恢复的服务。
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_cold_start_restore', false);

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(keepAliveCalls, isEmpty, reason: '关闭冷启动恢复后 resume 不得重新武装看门狗');
    });

    test('rearmKeepAliveOnResume does nothing when service is disabled',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', false);

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(keepAliveCalls, isEmpty);
    });

    test('rearmKeepAliveOnResume is a no-op on non-Android platforms',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await rearmKeepAliveOnResume();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(keepAliveCalls, isEmpty);
    });
  });
}
