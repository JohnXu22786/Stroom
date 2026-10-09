import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/services/background_service.dart';
import 'package:stroom/services/storage_service.dart';

class _TestDocuments extends PathProviderPlatform {
  _TestDocuments(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _BackgroundServicePlatform extends FlutterBackgroundServicePlatform {
  bool running = false;
  int stopCalls = 0;
  int startCalls = 0;
  Completer<void>? stopRequested;
  Completer<void>? secondStopRequested;
  Completer<void>? releaseStop;
  Completer<void>? startEntered;
  Completer<void>? releaseStart;

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async =>
      true;

  @override
  Future<bool> start() async {
    startCalls++;
    running = true;
    final entered = startEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await releaseStart?.future;
    return true;
  }

  @override
  Future<bool> isServiceRunning() async => running;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    if (method == 'stopService') {
      stopCalls++;
      final pending = stopRequested;
      if (pending != null && !pending.isCompleted) pending.complete();
      final secondPending = secondStopRequested;
      if (stopCalls == 2 &&
          secondPending != null &&
          !secondPending.isCompleted) {
        secondPending.complete();
      }
      final release = releaseStop;
      if (release == null) {
        running = false;
      } else {
        unawaited(release.future.then((_) {
          running = false;
        }));
      }
    }
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
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

class _CleanupCatCatchNotifier extends CatCatchNotifier {
  _CleanupCatCatchNotifier(super.ref);

  void setTasksForTest(List<CatCatchTask> tasks) => state = tasks;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatCatchNotifier background service ownership', () {
    late Directory directory;
    late _BackgroundServicePlatform servicePlatform;
    late PathProviderPlatform originalPathProvider;
    late ProviderContainer container;
    late _CleanupCatCatchNotifier notifier;
    late SharedPreferences preferences;
    late TargetPlatform? originalTargetPlatform;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      resetBackgroundServiceLifecycleStateForTesting();
      originalPathProvider = PathProviderPlatform.instance;
      originalTargetPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      servicePlatform = _BackgroundServicePlatform();
      FlutterBackgroundServicePlatform.instance = servicePlatform;
      directory = await Directory.systemTemp.createTemp('catcatch_service_');
      PathProviderPlatform.instance = _TestDocuments(directory.path);
      AppStorage.resetCache();
      container = ProviderContainer(overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          notifier = _CleanupCatCatchNotifier(ref);
          return notifier;
        }),
      ]);
      container.read(catcatchTasksProvider);
      preferences = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      container.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      debugDefaultTargetPlatformOverride = originalTargetPlatform;
      AppStorage.resetCache();
      await directory.delete(recursive: true);
    });

    CatCatchTask task(String id) => CatCatchTask(
          id: id,
          url: 'https://example.com/video.mp4',
          expectedDurationSec: 30,
          status: TaskStatus.paused,
          createdAt: DateTime(2025, 1, 1),
        );

    test('persisted removal preserves a user-enabled service', () async {
      await preferences.setBool('background_service_enabled', true);
      await notifier.startBackgroundServiceForTask();
      notifier.setTasksForTest([task('persistent-remove')]);

      expect(
          await notifier.removeTasksPersisted(['persistent-remove']), isTrue);

      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('ordinary cleanup preserves a user-enabled service', () async {
      await preferences.setBool('background_service_enabled', true);
      await notifier.startBackgroundServiceForTask();
      notifier.setTasksForTest([task('persistent-ordinary')]);

      notifier.removeTask('persistent-ordinary');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('ordinary cleanup stops a CatCatch-only service without persisting it',
        () async {
      await preferences.setBool('background_service_enabled', false);
      await notifier.startBackgroundServiceForTask();
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isFalse);

      servicePlatform.stopRequested = Completer<void>();
      notifier.setTasksForTest([task('temporary-ordinary')]);
      notifier.removeTask('temporary-ordinary');
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );

      expect(servicePlatform.stopCalls, 1);
      expect(servicePlatform.running, isFalse);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('persisted cleanup still stops a temporary service', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.running = true;
      notifier.setTasksForTest([task('temporary-persisted')]);

      expect(
          await notifier.removeTasksPersisted(['temporary-persisted']), isTrue);

      expect(servicePlatform.stopCalls, 1);
      expect(servicePlatform.running, isFalse);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('cleanup preserves user intent when persisting it fails', () async {
      await preferences.setBool('background_service_enabled', false);
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingEnabledPreferenceStore({
        'flutter.background_service_enabled': false,
      });
      try {
        await preferences.reload();
        expect(await startBackgroundService(), isTrue);
        await preferences.reload();
        expect(preferences.getBool('background_service_enabled'), isFalse);

        notifier.setTasksForTest([task('failed-preference-write')]);
        expect(
          await notifier.removeTasksPersisted(['failed-preference-write']),
          isTrue,
        );

        expect(servicePlatform.stopCalls, 0);
        expect(servicePlatform.running, isTrue);
      } finally {
        SharedPreferencesStorePlatform.instance = originalStore;
      }
    });

    test('cleanup honors an explicit stop when persisting it fails', () async {
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingEnabledPreferenceStore({
        'flutter.background_service_enabled': true,
      });
      try {
        await preferences.reload();
        expect(await startBackgroundService(), isTrue);
        expect(await stopBackgroundService(), isTrue);
        await preferences.reload();
        expect(preferences.getBool('background_service_enabled'), isTrue);
        expect(servicePlatform.running, isFalse);

        expect(await notifier.startBackgroundServiceForTask(), isTrue);
        notifier.setTasksForTest([task('failed-disable-write')]);
        expect(
          await notifier.removeTasksPersisted(['failed-disable-write']),
          isTrue,
        );

        expect(servicePlatform.stopCalls, 2);
        expect(servicePlatform.running, isFalse);
      } finally {
        SharedPreferencesStorePlatform.instance = originalStore;
      }
    });

    test('cleanup does not race a concurrent user-enabled start', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();

      final start = startBackgroundService();
      await servicePlatform.startEntered!.future.timeout(
        const Duration(seconds: 2),
      );
      notifier.setTasksForTest([task('concurrent-start')]);
      final cleanup = notifier.removeTasksPersisted(['concurrent-start']);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      servicePlatform.releaseStart!.complete();

      expect(await start, isTrue);
      expect(await cleanup, isTrue);
      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('a user start waits for an in-flight CatCatch cleanup stop', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.running = true;
      servicePlatform.stopRequested = Completer<void>();
      servicePlatform.releaseStop = Completer<void>();
      notifier.setTasksForTest([task('cleanup-before-start')]);

      final cleanup = notifier.removeTasksPersisted(['cleanup-before-start']);
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );
      final start = startBackgroundService();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(preferences.getBool('background_service_enabled'), isFalse);
      expect(servicePlatform.running, isTrue);

      servicePlatform.releaseStop!.complete();
      expect(await cleanup, isTrue);
      expect(await start, isTrue);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('a user start reconciles a timed-out stop before reporting active',
        () async {
      expect(await startBackgroundService(), isTrue);
      servicePlatform.stopRequested = Completer<void>();
      servicePlatform.secondStopRequested = Completer<void>();
      servicePlatform.releaseStop = Completer<void>();

      final stop = stopBackgroundService();
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );
      final result = await stop.timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          servicePlatform.releaseStop!.complete();
          return stop;
        },
      );

      expect(result, isFalse);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);

      var startCompleted = false;
      final start = startBackgroundService().then((result) {
        startCompleted = true;
        return result;
      });
      try {
        await servicePlatform.secondStopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(startCompleted, isFalse);
        expect(servicePlatform.startCalls, 1);
        servicePlatform.releaseStop!.complete();
        expect(await start, isTrue);
      } finally {
        if (!servicePlatform.releaseStop!.isCompleted) {
          servicePlatform.releaseStop!.complete();
        }
      }

      expect(servicePlatform.startCalls, 2);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });
  });
}
