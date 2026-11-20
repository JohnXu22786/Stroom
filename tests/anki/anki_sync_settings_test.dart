// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';

class _RejectedWriteStore extends InMemorySharedPreferencesStore {
  _RejectedWriteStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _RejectedSelectedWriteStore extends InMemorySharedPreferencesStore {
  _RejectedSelectedWriteStore(super.data, this.rejectedKey) : super.withData();

  final String rejectedKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == rejectedKey) return false;
    return super.setValue(valueType, key, value);
  }
}

class _SlowFirstUrlWriteStore extends InMemorySharedPreferencesStore {
  _SlowFirstUrlWriteStore(super.data) : super.withData();

  final firstUrlWriteStarted = Completer<void>();
  final rejectFirstUrlWrite = Completer<void>();
  var _urlWriteCount = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.custom_sync_server_collection_url' &&
        _urlWriteCount++ == 0) {
      firstUrlWriteStarted.complete();
      await rejectFirstUrlWrite.future;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the old enabled custom server to self-hosted mode', () async {
    SharedPreferences.setMockInitialValues({
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': 'https://sync.example.invalid/sync/',
      'custom_sync_certificate': 'test-ca',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = Completer<AnkiSyncState>();
    final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
      _,
      next,
    ) {
      if (next.isLoaded && !loaded.isCompleted) loaded.complete(next);
    }, fireImmediately: true);
    addTearDown(subscription.close);

    final state = await loaded.future.timeout(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();

    expect(state.mode, AnkiSyncMode.selfHosted);
    expect(state.selfHostedUrl, 'https://sync.example.invalid/sync/');
    expect(state.certificate, 'test-ca');
    expect(prefs.getString('anki_sync_mode'), 'selfHosted');
  });

  test('defaults older installs without custom sync to AnkiWeb', () async {
    SharedPreferences.setMockInitialValues({
      'custom_sync_server_enabled': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = Completer<AnkiSyncState>();
    final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
      _,
      next,
    ) {
      if (next.isLoaded && !loaded.isCompleted) loaded.complete(next);
    }, fireImmediately: true);
    addTearDown(subscription.close);

    final state = await loaded.future.timeout(const Duration(seconds: 2));

    expect(state.mode, AnkiSyncMode.ankiWeb);
    expect(state.isConfigured, isTrue);
  });

  test('a rejected mode write leaves the selected mode unchanged', () async {
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'ankiWeb',
      'custom_sync_server_enabled': false,
    });
    final store = _RejectedSelectedWriteStore({
      'flutter.anki_sync_mode': 'ankiWeb',
      'flutter.custom_sync_server_enabled': false,
    }, 'flutter.anki_sync_mode');
    SharedPreferencesStorePlatform.instance = store;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = Completer<void>();
    final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
      _,
      next,
    ) {
      if (next.isLoaded && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await loaded.future.timeout(const Duration(seconds: 2));

    await expectLater(
      container
          .read(ankiSyncProvider.notifier)
          .setMode(AnkiSyncMode.selfHosted),
      throwsA(isA<StateError>()),
    );

    expect(container.read(ankiSyncProvider).mode, AnkiSyncMode.ankiWeb);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('anki_sync_mode'), 'ankiWeb');
    expect(await store.getAll(), {
      'flutter.anki_sync_mode': 'ankiWeb',
      'flutter.custom_sync_server_enabled': false,
    });
  });

  test(
    'a rejected legacy enabled write does not publish the new mode',
    () async {
      SharedPreferences.setMockInitialValues({
        'anki_sync_mode': 'ankiWeb',
        'custom_sync_server_enabled': false,
      });
      final store = _RejectedSelectedWriteStore({
        'flutter.anki_sync_mode': 'ankiWeb',
        'flutter.custom_sync_server_enabled': false,
      }, 'flutter.custom_sync_server_enabled');
      SharedPreferencesStorePlatform.instance = store;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
        _,
        next,
      ) {
        if (next.isLoaded && !loaded.isCompleted) loaded.complete();
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await loaded.future.timeout(const Duration(seconds: 2));

      await expectLater(
        container
            .read(ankiSyncProvider.notifier)
            .setMode(AnkiSyncMode.selfHosted),
        throwsA(isA<StateError>()),
      );

      expect(container.read(ankiSyncProvider).mode, AnkiSyncMode.ankiWeb);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('anki_sync_mode'), 'ankiWeb');
      expect(prefs.getBool('custom_sync_server_enabled'), false);
    },
  );

  test('a failed second mode write rolls back the first stored key', () async {
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'ankiWeb',
      'custom_sync_server_enabled': false,
    });
    final store = _RejectedSelectedWriteStore({
      'flutter.anki_sync_mode': 'ankiWeb',
      'flutter.custom_sync_server_enabled': false,
    }, 'flutter.custom_sync_server_enabled');
    SharedPreferencesStorePlatform.instance = store;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = Completer<void>();
    final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
      _,
      next,
    ) {
      if (next.isLoaded && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await loaded.future.timeout(const Duration(seconds: 2));

    await expectLater(
      container
          .read(ankiSyncProvider.notifier)
          .setMode(AnkiSyncMode.selfHosted),
      throwsA(isA<StateError>()),
    );

    expect(await store.getAll(), {
      'flutter.anki_sync_mode': 'ankiWeb',
      'flutter.custom_sync_server_enabled': false,
    });
    expect(container.read(ankiSyncProvider).mode, AnkiSyncMode.ankiWeb);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('anki_sync_mode'), 'ankiWeb');
    expect(prefs.getBool('custom_sync_server_enabled'), false);
  });

  test('a rejected URL write leaves the in-memory URL unchanged', () async {
    const savedUrl = 'https://saved.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({
      'custom_sync_server_collection_url': savedUrl,
    });
    SharedPreferencesStorePlatform.instance = _RejectedWriteStore({
      'flutter.custom_sync_server_collection_url': savedUrl,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = Completer<void>();
    final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
      _,
      next,
    ) {
      if (next.isLoaded && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await loaded.future.timeout(const Duration(seconds: 2));
    final notifier = container.read(ankiSyncProvider.notifier);

    await expectLater(
      notifier.setSyncUrl('https://new.example.invalid/sync/'),
      throwsA(isA<StateError>()),
    );

    expect(container.read(ankiSyncProvider).selfHostedUrl, savedUrl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('custom_sync_server_collection_url'), savedUrl);
    expect(
      (await SharedPreferencesStorePlatform.instance
          .getAll())['flutter.custom_sync_server_collection_url'],
      savedUrl,
    );
  });

  test(
    'a rejected certificate write leaves the in-memory certificate unchanged',
    () async {
      const savedCertificate = 'saved certificate';
      SharedPreferences.setMockInitialValues({
        'custom_sync_certificate': savedCertificate,
      });
      SharedPreferencesStorePlatform.instance = _RejectedWriteStore({
        'flutter.custom_sync_certificate': savedCertificate,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
        _,
        next,
      ) {
        if (next.isLoaded && !loaded.isCompleted) loaded.complete();
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await loaded.future.timeout(const Duration(seconds: 2));
      final notifier = container.read(ankiSyncProvider.notifier);

      await expectLater(
        notifier.setCertificate('new certificate'),
        throwsA(isA<StateError>()),
      );

      expect(container.read(ankiSyncProvider).certificate, savedCertificate);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_sync_certificate'), savedCertificate);
      expect(
        (await SharedPreferencesStorePlatform.instance
            .getAll())['flutter.custom_sync_certificate'],
        savedCertificate,
      );
    },
  );

  test(
    'a failed earlier URL save cannot roll back a later successful save',
    () async {
      const savedUrl = 'https://saved.example.invalid/sync/';
      SharedPreferences.setMockInitialValues({
        'custom_sync_server_collection_url': savedUrl,
      });
      final store = _SlowFirstUrlWriteStore({
        'flutter.custom_sync_server_collection_url': savedUrl,
      });
      SharedPreferencesStorePlatform.instance = store;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen<AnkiSyncState>(ankiSyncProvider, (
        _,
        next,
      ) {
        if (next.isLoaded && !loaded.isCompleted) loaded.complete();
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await loaded.future.timeout(const Duration(seconds: 2));
      final notifier = container.read(ankiSyncProvider.notifier);

      final failedSave = notifier.setSyncUrl(
        'https://first.example.invalid/sync/',
      );
      await store.firstUrlWriteStarted.future.timeout(
        const Duration(seconds: 2),
      );
      final successfulSave = notifier.setSyncUrl(
        'https://second.example.invalid/sync/',
      );
      store.rejectFirstUrlWrite.complete();

      await expectLater(failedSave, throwsA(isA<StateError>()));
      await successfulSave;

      const finalUrl = 'https://second.example.invalid/sync/';
      expect(container.read(ankiSyncProvider).selfHostedUrl, finalUrl);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_sync_server_collection_url'), finalUrl);
      expect(
        (await store.getAll())['flutter.custom_sync_server_collection_url'],
        finalUrl,
      );
    },
  );
}
