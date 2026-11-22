// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/providers/tts_state_provider.dart';

class _FailingInitializationStore extends InMemorySharedPreferencesStore {
  _FailingInitializationStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async {
    throw StateError('preferences initialization failed');
  }
}

class _FailingWriteStore extends InMemorySharedPreferencesStore {
  _FailingWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _FailingMigrationWriteStore extends InMemorySharedPreferencesStore {
  _FailingMigrationWriteStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _ThrowingMigrationWriteStore extends InMemorySharedPreferencesStore {
  _ThrowingMigrationWriteStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw StateError('migration write failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'initialization failure is observable and leaves config unchanged',
    () async {
      SharedPreferencesStorePlatform.instance = _FailingInitializationStore();
      final notifier = SynthesisConfigNotifier();
      final original = notifier.state;

      await expectLater(
        notifier.saveConfig(const SynthesisConfig(voice: 'nova')),
        throwsA(isA<StateError>()),
      );

      expect(notifier.state, same(original));
      notifier.dispose();
    },
  );

  test('write failure is observable and leaves config unchanged', () async {
    SharedPreferencesStorePlatform.instance = _FailingWriteStore();
    final notifier = SynthesisConfigNotifier();
    final original = notifier.state;

    await expectLater(
      notifier.saveConfig(const SynthesisConfig(voice: 'nova')),
      throwsA(isA<StateError>()),
    );

    expect(notifier.state, same(original));
    notifier.dispose();
  });

  test('failed voice migration keeps the persisted config in state', () async {
    const legacyVoice = '女声';
    const persistedConfig = SynthesisConfig(
      voice: legacyVoice,
      speed: 1.25,
      format: 'mp3',
    );
    SharedPreferencesStorePlatform.instance = _FailingMigrationWriteStore({
      'flutter.synthesis_config': jsonEncode(persistedConfig.toMap()),
    });
    final notifier = SynthesisConfigNotifier();

    await notifier.loadConfig();

    expect(notifier.state.voice, legacyVoice);
    expect(notifier.state.speed, persistedConfig.speed);
    expect(notifier.state.format, persistedConfig.format);
    final stored = await SharedPreferencesStorePlatform.instance.getAll();
    expect(
      jsonDecode(stored['flutter.synthesis_config']! as String)['voice'],
      legacyVoice,
    );
    notifier.dispose();
  });

  test('thrown voice migration write keeps the persisted config in state',
      () async {
    const legacyVoice = '女声';
    const persistedConfig = SynthesisConfig(
      voice: legacyVoice,
      speed: 1.25,
      format: 'mp3',
    );
    SharedPreferencesStorePlatform.instance = _ThrowingMigrationWriteStore({
      'flutter.synthesis_config': jsonEncode(persistedConfig.toMap()),
    });
    final notifier = SynthesisConfigNotifier();

    await notifier.loadConfig();

    expect(notifier.state.voice, legacyVoice);
    expect(notifier.state.speed, persistedConfig.speed);
    expect(notifier.state.format, persistedConfig.format);
    notifier.dispose();
  });

  test('successful save persists config before publishing state', () async {
    final store = InMemorySharedPreferencesStore.empty();
    SharedPreferencesStorePlatform.instance = store;
    final notifier = SynthesisConfigNotifier();
    final config = const SynthesisConfig(voice: 'nova', speed: 1.25);

    await notifier.saveConfig(config);

    expect(notifier.state.voice, config.voice);
    expect(notifier.state.speed, config.speed);
    final persisted = await store.getAll();
    final savedConfig = jsonDecode(
      persisted['flutter.synthesis_config']! as String,
    ) as Map<String, dynamic>;
    expect(savedConfig['voice'], 'nova');
    expect(savedConfig['speed'], 1.25);
    expect(notifier.state.voice, 'nova');
    notifier.dispose();
  });

  test(
    'concurrent field updates compose without losing earlier changes',
    () async {
      final notifier = SynthesisConfigNotifier();

      await Future.wait([
        notifier.updateVoice('nova'),
        notifier.updateSpeed(1.25),
        notifier.updateVolume(0.75),
      ]);

      expect(notifier.state.voice, 'nova');
      expect(notifier.state.speed, 1.25);
      expect(notifier.state.volume, 0.75);
      final prefs = await SharedPreferences.getInstance();
      final savedConfig = jsonDecode(
        prefs.getString('synthesis_config')!,
      ) as Map<String, dynamic>;
      expect(savedConfig['voice'], 'nova');
      expect(savedConfig['speed'], 1.25);
      expect(savedConfig['volume'], 0.75);
      notifier.dispose();
    },
  );
}
