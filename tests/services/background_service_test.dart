import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
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
  bool _deferStopCompletion = false;
  bool _stopRequested = false;
  bool _holdStoppedCheck = false;
  Completer<void>? _stoppedCheckStarted;
  Completer<void>? _releaseStoppedCheck;
  final Set<int> _throwOnCheckCalls = {};
  int _serviceRunningCheckCount = 0;

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

  void deferStopCompletion() {
    _deferStopCompletion = true;
  }

  void holdStoppedCheck() {
    _holdStoppedCheck = true;
    _stoppedCheckStarted = Completer<void>();
    _releaseStoppedCheck = Completer<void>();
  }

  Future<void> get stoppedCheckStarted => _stoppedCheckStarted!.future;

  void releaseStoppedCheck() {
    _releaseStoppedCheck!.complete();
  }

  void completeDelayedStop() {
    if (!_stopRequested) {
      throw StateError('No stop request is pending.');
    }
    _isRunning = false;
  }

  void setThrowOnCheckCalls(Set<int> calls) {
    _throwOnCheckCalls.addAll(calls);
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
    _serviceRunningCheckCount++;
    if (_throwOnCheck ||
        _throwOnCheckCalls.contains(_serviceRunningCheckCount)) {
      throw 'Simulated check error';
    }
    final isRunning = _isRunning;
    if (!isRunning && _holdStoppedCheck) {
      _holdStoppedCheck = false;
      _stoppedCheckStarted!.complete();
      await _releaseStoppedCheck!.future;
    }
    return isRunning;
  }

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    if (method == 'stopService') {
      _stopRequested = true;
      if (!_deferStopCompletion) _isRunning = false;
    }
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    return const Stream.empty();
  }
}

class _FailingEnabledPreferenceStore extends InMemorySharedPreferencesStore {
  _FailingEnabledPreferenceStore(Map<String, Object> data)
      : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'Bool' && key == 'flutter.background_service_enabled') {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _FailingPreferenceReadStore extends InMemorySharedPreferencesStore {
  _FailingPreferenceReadStore(Map<String, Object> data) : super.withData(data);

  @override
  Future<Map<String, Object>> getAll() async {
    throw StateError('Simulated preference read error');
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
    this.throwOnWrite = false,
  })  : _failedKeys = failedKeys,
        super.withData(data);

  final Set<String> _failedKeys;
  final bool throwOnWrite;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'Bool' && _failedKeys.contains(key)) {
      if (throwOnWrite) {
        return Future<bool>.error(
            StateError('Simulated preference write error'));
      }
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _DelayedRejectedWatchdogWriteStore
    extends InMemorySharedPreferencesStore {
  _DelayedRejectedWatchdogWriteStore(Map<String, Object> data)
      : super.withData(data);

  final firstWatchdogWriteStarted = Completer<void>();
  final releaseFirstWatchdogWrite = Completer<void>();
  int watchdogEnableWriteCount = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (valueType == 'Bool' &&
        key == 'flutter.background_service_watchdog' &&
        value == true) {
      watchdogEnableWriteCount++;
      if (watchdogEnableWriteCount == 1) {
        firstWatchdogWriteStarted.complete();
        await releaseFirstWatchdogWrite.future;
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

Future<SharedPreferencesStorePlatform> _rejectEnabledPreferenceWrites(
    SharedPreferences preferences,
    {bool initiallyEnabled = false}) async {
  final originalStore = SharedPreferencesStorePlatform.instance;
  SharedPreferencesStorePlatform.instance = _FailingEnabledPreferenceStore({
    'flutter.background_service_enabled': initiallyEnabled,
  });
  await preferences.reload();
  return originalStore;
}

Future<SharedPreferencesStorePlatform>
    _rejectDesktopCloseMinimizePreferenceWrites(
        SharedPreferences preferences) async {
  final originalStore = SharedPreferencesStorePlatform.instance;
  SharedPreferencesStorePlatform.instance =
      _FailingDesktopCloseMinimizePreferenceStore({
    'flutter.desktop_close_minimize': true,
  });
  await preferences.reload();
  return originalStore;
}

Future<SharedPreferencesStorePlatform> _failRecoveryPreferenceWrites(
  SharedPreferences preferences, {
  required bool throwOnWrite,
}) async {
  final originalStore = SharedPreferencesStorePlatform.instance;
  SharedPreferencesStorePlatform.instance = _FailingRecoveryPreferenceStore(
    {
      'flutter.background_service_watchdog': false,
      'flutter.background_service_cold_start_restore': false,
    },
    failedKeys: {
      'flutter.background_service_watchdog',
      'flutter.background_service_cold_start_restore',
    },
    throwOnWrite: throwOnWrite,
  );
  await preferences.reload();
  return originalStore;
}

/// Records method calls made on the keep-alive method channel.
final List<MethodCall> keepAliveCalls = [];
bool keepAliveSchedulingResult = true;

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
    // The in-process user choice must not leak between test cases.
    resetBackgroundServiceLifecycleStateForTesting();
    SharedPreferences.setMockInitialValues({});
    keepAliveCalls.clear();
    keepAliveSchedulingResult = true;
    // Set up a mock MethodChannel handler so keep-alive calls complete with
    // the result selected by each test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.johntsui.stroom/keepalive'),
      (MethodCall methodCall) async {
        keepAliveCalls.add(methodCall);
        return keepAliveSchedulingResult;
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
        'cold start during completed stop request does not restore explicit stop',
        () async {
      final mock = registerMockPlatform()
        ..setServiceRunning(true)
        ..holdStoppedCheck();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await withAndroidPlatform(() async {
        final stopping = stopBackgroundService();
        await mock.stoppedCheckStarted;

        // The stop request has taken effect. Simulate a new process before
        // the old stop path would persist enabled=false.
        resetBackgroundServiceLifecycleStateForTesting();
        await restoreBackgroundServiceOnColdStart();
        final restoredDuringStop = mock._isRunning;

        mock.releaseStoppedCheck();
        expect(await stopping, isTrue);
        expect(
          restoredDuringStop,
          isFalse,
          reason: 'cold-start restore must see the stop intent even after the '
              'service has stopped but before the stop operation returns',
        );
      });
    });

    test('stopBackgroundService persists stop intent before disabling watchdog',
        () async {
      final mock = registerMockPlatform()..setServiceRunning(true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      var enabledWhenWatchdogDisabled = true;

      // Model a process restart at the boundary where the native watchdog is
      // disabled. The cold-start decision must already see the durable stop.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall methodCall) async {
          keepAliveCalls.add(methodCall);
          if (methodCall.method == 'stopKeepAlive') {
            await prefs.reload();
            enabledWhenWatchdogDisabled =
                prefs.getBool('background_service_enabled') ?? true;
            resetBackgroundServiceLifecycleStateForTesting();
            await restoreBackgroundServiceOnColdStart();
          }
          return true;
        },
      );

      await withAndroidPlatform(() async {
        expect(await stopBackgroundService(), isTrue);
      });

      expect(enabledWhenWatchdogDisabled, isFalse);
      expect(
        mock._isRunning,
        isFalse,
        reason: 'a cold start at watchdog cancellation must not restore the '
            'explicitly stopped service',
      );
    });

    test(
        'stopBackgroundService does not cancel watchdog when persistence fails',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);

      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _rejectEnabledPreferenceWrites(
        prefs,
        initiallyEnabled: true,
      );
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await stopBackgroundService(), isFalse);
        await prefs.reload();
        expect(prefs.getBool('background_service_enabled'), isTrue);
        await rearmKeepAliveOnResume();
      });

      expect(mock._isRunning, isFalse);
      expect(
        keepAliveCalls.any((call) => call.method == 'stopKeepAlive'),
        isFalse,
        reason: 'a rejected stop intent must not leave the persisted enabled '
            'state without watchdog recovery',
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'rearmKeepAlive'),
        isFalse,
      );
    });

    test('failed stop request restores enabled intent and watchdog recovery',
        () async {
      final mock = registerMockPlatform()
        ..setServiceRunning(true)
        ..setThrowOnCheckCalls({2});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await withAndroidPlatform(() async {
        expect(await stopBackgroundService(), isFalse);
        await prefs.reload();
        expect(prefs.getBool('background_service_enabled'), isTrue);
      });

      expect(
        keepAliveCalls.any((call) => call.method == 'stopKeepAlive'),
        isFalse,
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'rearmKeepAlive'),
        isTrue,
        reason: 'a failed stop must retain enabled intent and recovery',
      );
      expect(mock._isRunning, isFalse);
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

    test(
        'restoreBackgroundServiceOnColdStart recovers when enabled preference read fails',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferenceReadStore({
        'flutter.background_service_enabled': true,
      });
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        await restoreBackgroundServiceOnColdStart();
      });

      expect(mock._isRunning, isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('rearmKeepAlive'),
      );
    });

    test(
        'failed persistent start cannot rely on in-process intent after process death',
        () async {
      final mock = registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _rejectEnabledPreferenceWrites(prefs);
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
        expect(prefs.getBool('background_service_enabled'), isFalse);

        // A process-only explicit choice must not be what makes this look
        // recoverable after a cold start.
        resetBackgroundServiceLifecycleStateForTesting();
        mock.setServiceRunning(false);
        await restoreBackgroundServiceOnColdStart();
      });

      expect(mock._isRunning, isFalse);
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
        reason: 'a failed persistent start must not arm a watchdog behind a '
            'false enabled preference',
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'rearmKeepAlive'),
        isFalse,
      );
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
        'restoreBackgroundServiceOnColdStart keeps service stopped but rearms '
        'watchdog when cold-start restore is off', () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setStartResult(true);

      // Service was previously enabled...
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_watchdog', true);
      // ...but the user disabled cold-start auto-restore.
      await setColdStartRestoreEnabled(false);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await restoreBackgroundServiceOnColdStart();
        // Service must NOT be started
        expect(mock._isRunning, isFalse);
        expect(prefs.getBool('background_service_enabled'), isTrue);
        expect(
          keepAliveCalls.map((call) => call.method),
          contains('rearmKeepAlive'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('BackgroundService - keep-alive strategy toggles', () {
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

    test('recovery toggle setters report rejected preference writes', () async {
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _failRecoveryPreferenceWrites(
        prefs,
        throwOnWrite: false,
      );
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      expect(await setWatchdogEnabled(true), isFalse);
      expect(await setColdStartRestoreEnabled(true), isFalse);
      expect(prefs.getBool('background_service_watchdog'), isFalse);
      expect(prefs.getBool('background_service_cold_start_restore'), isFalse);
    });

    test('recovery toggle setters report preference write errors', () async {
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _failRecoveryPreferenceWrites(
        prefs,
        throwOnWrite: true,
      );
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      expect(await setWatchdogEnabled(true), isFalse);
      expect(await setColdStartRestoreEnabled(true), isFalse);
      expect(prefs.getBool('background_service_watchdog'), isFalse);
      expect(prefs.getBool('background_service_cold_start_restore'), isFalse);
    });

    test('a failed watchdog write cannot roll back a later successful write',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final originalStore = SharedPreferencesStorePlatform.instance;
      final store = _DelayedRejectedWatchdogWriteStore({
        'flutter.background_service_watchdog': false,
      });
      SharedPreferencesStorePlatform.instance = store;
      await prefs.reload();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      final failedWrite = setWatchdogEnabled(true);
      await store.firstWatchdogWriteStarted.future;
      final successfulWrite = setWatchdogEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final writesBeforeFirstCompletes = store.watchdogEnableWriteCount;
      store.releaseFirstWatchdogWrite.complete();

      expect(await failedWrite, isFalse);
      expect(await successfulWrite, isTrue);
      expect(writesBeforeFirstCompletes, 1);
      expect(prefs.getBool('background_service_watchdog'), isTrue);
    });

    test('battery reminder toggle defaults to enabled and persists', () async {
      expect(await isBatteryReminderEnabled(), isTrue);
      await setBatteryReminderEnabled(false);
      expect(await isBatteryReminderEnabled(), isFalse);
    });

    test('desktop close-minimize toggle defaults to enabled and persists',
        () async {
      expect(await isDesktopCloseMinimizeEnabled(), isTrue);
      await expectLater(
        setDesktopCloseMinimizeEnabled(false),
        completion(isTrue),
      );
      expect(await isDesktopCloseMinimizeEnabled(), isFalse);
    });

    test('desktop close-minimize reports a rejected preference write',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final originalStore =
          await _rejectDesktopCloseMinimizePreferenceWrites(prefs);
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await expectLater(
        setDesktopCloseMinimizeEnabled(false),
        completion(isFalse),
      );
      await prefs.reload();
      expect(prefs.getBool('desktop_close_minimize'), isTrue);
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

    test('restart timeout arms watchdog when the stop request completes late',
        () async {
      final mock = registerMockPlatform()
        ..setServiceRunning(true)
        ..deferStopCompletion();
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await restartBackgroundService(), isFalse);
        mock.completeDelayedStop();
        await prefs.reload();
      });

      expect(mock._isRunning, isFalse);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason: 'the late stop must not leave a persistently enabled service '
            'without watchdog recovery armed',
      );
    });

    test(
        'restartBackgroundService preserves a running service when enabled write is rejected',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(true);
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _rejectEnabledPreferenceWrites(prefs);
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await restartBackgroundService(), isFalse);
        await prefs.reload();
        expect(prefs.getBool('background_service_enabled'), isFalse);
      });

      expect(mock._isRunning, isTrue);
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
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

    test(
        'startBackgroundService reports watchdog scheduling failure without disabling the service',
        () async {
      final mock = registerMockPlatform();
      keepAliveSchedulingResult = false;
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(mock._isRunning, isTrue);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isTrue,
      );
    });

    test(
        'failed persistent start schedules watchdog retry and preserves enabled intent',
        () async {
      final mock = registerMockPlatform()..setStartResult(false);
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(mock._isRunning, isFalse);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason: 'a failed persistent start must leave a later watchdog retry',
      );
    });

    test(
        'persistent start exception schedules watchdog retry and preserves enabled intent',
        () async {
      final mock = registerMockPlatform()..setThrowOnStart(true);
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason: 'a persistent start exception must leave a watchdog retry',
      );
    });

    test(
        'persistent running check exception schedules watchdog retry and preserves enabled intent',
        () async {
      registerMockPlatform()..setThrowOnCheck(true);
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason:
            'a persistent running check exception must leave a watchdog retry',
      );
    });

    test(
        'pending stop running check exception schedules watchdog retry and preserves enabled intent',
        () async {
      registerMockPlatform()
        ..setServiceRunning(true)
        ..setThrowOnCheckCalls({2, 3});
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await stopBackgroundService(), isFalse);
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason:
            'a pending-stop running check exception must leave a watchdog retry',
      );
    });

    test('failed temporary start does not arm the watchdog', () async {
      final mock = registerMockPlatform()..setStartResult(false);

      await withAndroidPlatform(() async {
        expect(
          await startBackgroundService(persistEnabled: false),
          isFalse,
        );
      });

      expect(mock._isRunning, isFalse);
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('temporary start leaves disabled persistent intent unchanged',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', false);

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(persistEnabled: false), isTrue);
        await prefs.reload();
      });

      expect(prefs.getBool('background_service_enabled'), isFalse);
      expect(keepAliveCalls, isEmpty);
    });

    test(
        'temporary start does not assume unreadable persistent intent is enabled',
        () async {
      registerMockPlatform();
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferenceReadStore({
        'flutter.background_service_enabled': false,
      });
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(persistEnabled: false), isTrue);
      });

      expect(keepAliveCalls, isEmpty);
    });

    test('temporary start rearms watchdog when persistent intent is enabled',
        () async {
      final mock = registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(persistEnabled: false), isTrue);
        await prefs.reload();
      });

      expect(mock._isRunning, isTrue);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('rearmKeepAlive'),
      );
      expect(
        keepAliveCalls.map((call) => call.method),
        isNot(contains('startKeepAlive')),
        reason: 'a temporary start must preserve watchdog backoff state',
      );
    });

    test('temporary start exception does not arm the watchdog', () async {
      final mock = registerMockPlatform()..setThrowOnStart(true);

      await withAndroidPlatform(() async {
        expect(
          await startBackgroundService(persistEnabled: false),
          isFalse,
        );
      });

      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('temporary running check exception does not arm the watchdog',
        () async {
      registerMockPlatform()..setThrowOnCheck(true);

      await withAndroidPlatform(() async {
        expect(
          await startBackgroundService(persistEnabled: false),
          isFalse,
        );
      });

      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('failed persistent start respects a disabled watchdog', () async {
      final mock = registerMockPlatform()..setStartResult(false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_watchdog', false);

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(mock._isRunning, isFalse);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(keepAliveCalls, isEmpty);
    });

    test(
        'failed persistent start does not call the watchdog channel off Android',
        () async {
      final mock = registerMockPlatform()..setStartResult(false);
      final prefs = await SharedPreferences.getInstance();

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(mock._isRunning, isFalse);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(keepAliveCalls, isEmpty);
    });

    test(
        'restartBackgroundService reports watchdog scheduling failure while preserving enabled intent',
        () async {
      final mock = registerMockPlatform()..setServiceRunning(true);
      keepAliveSchedulingResult = false;
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await restartBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(mock._isRunning, isTrue);
      expect(prefs.getBool('background_service_enabled'), isTrue);
    });

    test('failed restart schedules watchdog retry and preserves enabled intent',
        () async {
      final mock = registerMockPlatform()
        ..setServiceRunning(true)
        ..setStartResult(false);
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await restartBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(mock._isRunning, isFalse);
      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason: 'a failed restart must leave a later watchdog retry',
      );
    });

    test(
        'restart exception schedules watchdog retry and preserves enabled intent',
        () async {
      final mock = registerMockPlatform()
        ..setServiceRunning(true)
        ..setThrowOnStart(true);
      final prefs = await SharedPreferences.getInstance();

      await withAndroidPlatform(() async {
        expect(await restartBackgroundService(), isFalse);
        await prefs.reload();
      });

      expect(prefs.getBool('background_service_enabled'), isTrue);
      expect(
        keepAliveCalls.map((call) => call.method),
        contains('startKeepAlive'),
        reason: 'a restart exception must leave a watchdog retry',
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

    test('cold-start restore re-arms the watchdog when service startup throws',
        () async {
      final mock = registerMockPlatform();
      mock.setServiceRunning(false);
      mock.setThrowOnStart(true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);

      await withAndroidPlatform(() async {
        await restoreBackgroundServiceOnColdStart();
      });

      expect(
        keepAliveCalls.any((c) => c.method == 'rearmKeepAlive'),
        isTrue,
        reason: 'a failed restore must still schedule the watchdog retry',
      );
      expect(prefs.getBool('background_service_enabled'), isTrue,
          reason: 'a failed automatic restore must preserve the user choice');
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
      await prefs.setBool('background_service_watchdog', true);

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

    test('rearmKeepAliveOnResume serializes watchdog rearm with explicit stop',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_watchdog', true);

      final firstRearmStarted = Completer<void>();
      final releaseFirstRearm = Completer<void>();
      final resumeRearmStarted = Completer<void>();
      final releaseResumeRearm = Completer<void>();
      final stopKeepAliveStarted = Completer<void>();
      var rearmCount = 0;
      var watchdogArmed = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/keepalive'),
        (MethodCall methodCall) async {
          keepAliveCalls.add(methodCall);
          if (methodCall.method == 'rearmKeepAlive') {
            rearmCount++;
            if (rearmCount == 1) {
              firstRearmStarted.complete();
              await releaseFirstRearm.future;
            } else if (rearmCount == 2) {
              resumeRearmStarted.complete();
              await releaseResumeRearm.future;
            }
            watchdogArmed = true;
          } else if (methodCall.method == 'stopKeepAlive') {
            stopKeepAliveStarted.complete();
            watchdogArmed = false;
          }
          return true;
        },
      );

      await withAndroidPlatform(() async {
        final recovery = rearmBackgroundServiceWatchdog();
        await firstRearmStarted.future;

        final resume = rearmKeepAliveOnResume();
        // Let the unlocked resume path pass its enabled-intent check and pause
        // at the second rearm while the first operation still holds the lock.
        await Future<void>.delayed(Duration.zero);
        final stop = stopBackgroundService();
        releaseFirstRearm.complete();

        await resumeRearmStarted.future;
        await Future<void>.delayed(Duration.zero);
        final stopReachedNativeCancellation = stopKeepAliveStarted.isCompleted;
        releaseResumeRearm.complete();
        await Future.wait([recovery, resume, stop]);

        expect(
          watchdogArmed,
          isFalse,
          reason: 'a completed explicit stop must leave no watchdog alarm '
              'armed',
        );
        expect(
          stopReachedNativeCancellation,
          isFalse,
          reason: 'stop must wait until the resume rearm releases the '
              'lifecycle lock',
        );
      });
    });

    test('rearmKeepAliveOnResume proceeds when enabled preference read fails',
        () async {
      registerMockPlatform();
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferenceReadStore({
        'flutter.background_service_enabled': true,
      });
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(
        keepAliveCalls.map((call) => call.method),
        contains('rearmKeepAlive'),
      );
    });

    test('rearmKeepAliveOnResume reports watchdog scheduling failure',
        () async {
      registerMockPlatform();
      keepAliveSchedulingResult = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_watchdog', true);
      final loggedMessages = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) loggedMessages.add(message);
      };

      try {
        await withAndroidPlatform(() async {
          await rearmKeepAliveOnResume();
        });
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(
        loggedMessages,
        contains(
            '[BackgroundService] Android did not schedule the keep-alive alarm.'),
      );
    });

    test(
        'resume does not re-arm watchdog after persistent start write is rejected',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _rejectEnabledPreferenceWrites(prefs);
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        await prefs.reload();
        expect(prefs.getBool('background_service_enabled'), isFalse);
        await rearmKeepAliveOnResume();
      });

      expect(
        keepAliveCalls.any((call) => call.method == 'rearmKeepAlive'),
        isFalse,
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'startKeepAlive'),
        isFalse,
      );
    });

    test('resume does not re-arm after explicit stop despite rejected writes',
        () async {
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      final originalStore = await _rejectEnabledPreferenceWrites(prefs);
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalStore;
      });

      await withAndroidPlatform(() async {
        expect(await startBackgroundService(), isFalse);
        expect(await stopBackgroundService(), isTrue);
        await rearmKeepAliveOnResume();
      });

      expect(
        keepAliveCalls.any((call) => call.method == 'stopKeepAlive'),
        isTrue,
      );
      expect(
        keepAliveCalls.any((call) => call.method == 'rearmKeepAlive'),
        isFalse,
      );
    });

    test(
        'rearmKeepAliveOnResume ignores the cold-start toggle when the '
        'watchdog is on', () async {
      // 回归（round-8 撤销 round-7 门控）：冷启动恢复与看门狗是两个
      // 独立开关 —— 关闭冷启动恢复但看门狗开启时，resume 补武装
      // 仍然必须生效（精确闹钟被系统撤销时 resume 是唯一自愈时机）。
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_cold_start_restore', false);
      await prefs.setBool('background_service_watchdog', true);

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(
        keepAliveCalls.any((c) => c.method == 'rearmKeepAlive'),
        isTrue,
        reason: 'resume 补武装只看看门狗开关，与冷启动恢复开关无关',
      );
    });

    test('rearmKeepAliveOnResume respects the watchdog toggle', () async {
      // 看门狗开关是 resume 补武装的正确门控：关闭看门狗后回到前台
      // 不得重新武装（冷启动恢复开关与看门狗相互独立，不参与门控）。
      registerMockPlatform();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setBool('background_service_watchdog', false);

      await withAndroidPlatform(() async {
        await rearmKeepAliveOnResume();
      });

      expect(keepAliveCalls, isEmpty, reason: '关闭看门狗后 resume 不得重新武装闹钟');
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
