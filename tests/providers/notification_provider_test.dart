import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/providers/notification_provider.dart';
import 'package:stroom/services/notification_service.dart';

class _RejectNotificationWriteStore extends InMemorySharedPreferencesStore {
  _RejectNotificationWriteStore.withData(Map<String, Object> data)
      : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.notifications_enabled') return false;
    return super.setValue(valueType, key, value);
  }
}

class _DelayedRejectNotificationWriteStore
    extends InMemorySharedPreferencesStore {
  _DelayedRejectNotificationWriteStore.withData(Map<String, Object> data)
      : super.withData(data);

  final firstWriteStarted = Completer<void>();
  final rejectFirstWrite = Completer<void>();
  var _notificationWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.notifications_enabled' && _notificationWrites++ == 0) {
      firstWriteStarted.complete();
      await rejectFirstWrite.future;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rejected setting write throws and keeps the previous provider value',
    () async {
      SharedPreferences.setMockInitialValues({'notifications_enabled': true});
      SharedPreferencesStorePlatform.instance =
          _RejectNotificationWriteStore.withData({
        'flutter.notifications_enabled': true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(notificationSettingsProvider.notifier).load();

      await expectLater(
        container.read(notificationSettingsProvider.notifier).setEnabled(false),
        throwsA(isA<StateError>()),
      );

      expect(container.read(notificationSettingsProvider), isTrue);
      expect(await NotificationService().isEnabled, isTrue);
    },
  );

  test(
    'successful setting write updates persisted and provider values',
    () async {
      SharedPreferences.setMockInitialValues({'notifications_enabled': false});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(notificationSettingsProvider.notifier).load();
      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(true);

      expect(container.read(notificationSettingsProvider), isTrue);
      expect(await NotificationService().isEnabled, isTrue);
    },
  );

  test(
      'a failed pending write stays hidden from reads and later successful saves',
      () async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final store = _DelayedRejectNotificationWriteStore.withData({
      'flutter.notifications_enabled': false,
    });
    SharedPreferencesStorePlatform.instance = store;

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(notificationSettingsProvider.notifier).load();

    final failedSave =
        container.read(notificationSettingsProvider.notifier).setEnabled(false);
    await store.firstWriteStarted.future;
    var readCompleted = false;
    final readWhileSaving = NotificationService().isEnabled.then((value) {
      readCompleted = true;
      return value;
    });
    final successfulSave =
        container.read(notificationSettingsProvider.notifier).setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(readCompleted, isFalse);
    store.rejectFirstWrite.complete();

    await expectLater(failedSave, throwsA(isA<StateError>()));
    expect(await readWhileSaving, isFalse);
    await successfulSave;

    expect(container.read(notificationSettingsProvider), isTrue);
    expect(await NotificationService().isEnabled, isTrue);
  });
}
