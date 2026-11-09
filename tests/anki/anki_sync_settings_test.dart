// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';

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
}
