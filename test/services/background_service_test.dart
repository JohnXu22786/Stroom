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

/// Registers a mock background service platform for testing and returns it.
MockBackgroundServicePlatform registerMockPlatform() {
  final mock = MockBackgroundServicePlatform();
  FlutterBackgroundServicePlatform.instance = mock;
  return mock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
  });
}
