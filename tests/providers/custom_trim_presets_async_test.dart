// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, use_super_parameters

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/tts_config.dart';

class _DelayedInitializationStore extends InMemorySharedPreferencesStore {
  _DelayedInitializationStore.withData(Map<String, Object> data)
      : super.withData(data);

  final Completer<void> _initialization = Completer<void>();

  void completeInitialization() => _initialization.complete();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    await _initialization.future;
    return super.getAllWithParameters(parameters);
  }
}

void main() {
  const presetKey = 'custom_trim_presets';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('preserves malformed stored presets during load', () async {
    const malformedPresets = '[{"id":"broken"';
    SharedPreferences.setMockInitialValues({presetKey: malformedPresets});

    final notifier = CustomTrimPresetsNotifier();
    await notifier.load();

    final prefs = await SharedPreferences.getInstance();
    expect(notifier.state, isEmpty);
    expect(prefs.getString(presetKey), malformedPresets);
    expect(
      prefs.getKeys().where((key) => key.startsWith('$presetKey.corrupt.')),
      isEmpty,
    );
  });

  test(
    'backs up malformed presets before mutation and keeps them recoverable',
    () async {
      const malformedPresets = '[{"id":"broken"';
      SharedPreferences.setMockInitialValues({presetKey: malformedPresets});

      final notifier = CustomTrimPresetsNotifier();
      await notifier.load();
      await notifier.add(
        TrimPreset(id: 'added', name: 'Added', durationSeconds: 2.0),
      );

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('$presetKey.corrupt.'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), malformedPresets);

      final restartedNotifier = CustomTrimPresetsNotifier();
      await restartedNotifier.load();
      expect(restartedNotifier.state.map((preset) => preset.id), [
        'added',
      ]);
      expect(prefs.getString(backupKeys.single), malformedPresets);
    },
  );

  test('preserves valid preset ordering without a corrupt backup', () async {
    final storedPresets = [
      {
        'id': 'first',
        'name': 'First',
        'durationSeconds': 1.0,
        'direction': 'head',
      },
      {
        'id': 'second',
        'name': 'Second',
        'durationSeconds': 1.5,
        'direction': 'tail',
      },
    ];
    SharedPreferences.setMockInitialValues({
      presetKey: jsonEncode(storedPresets),
    });

    final notifier = CustomTrimPresetsNotifier();
    await notifier.load();
    await notifier.add(
      TrimPreset(id: 'added', name: 'Added', durationSeconds: 2.0),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(notifier.state.map((preset) => preset.id), [
      'first',
      'second',
      'added',
    ]);
    expect(
      prefs.getKeys().where((key) => key.startsWith('$presetKey.corrupt.')),
      isEmpty,
    );
    expect(
      (jsonDecode(prefs.getString(presetKey)!) as List).map(
        (preset) => preset['id'],
      ),
      ['first', 'second', 'added'],
    );
  });

  test('keeps a mutation made while loading saved presets', () async {
    final storedPreset = {
      'id': 'stored',
      'name': 'Stored',
      'durationSeconds': 1.0,
      'direction': 'head',
    };
    final store = _DelayedInitializationStore.withData({
      'flutter.$presetKey': jsonEncode([storedPreset]),
    });
    SharedPreferencesStorePlatform.instance = store;

    final notifier = CustomTrimPresetsNotifier();
    final observedStates = <List<TrimPreset>>[];
    notifier.addListener(observedStates.add);
    final load = notifier.load();
    final addedPreset = TrimPreset(
      id: 'added',
      name: 'Added',
      durationSeconds: 2.0,
    );
    final add = notifier.add(addedPreset);

    expect(observedStates.last.map((preset) => preset.id), ['added']);

    store.completeInitialization();
    await Future.wait([load, add]);

    expect(observedStates.last.map((preset) => preset.id), ['stored', 'added']);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(presetKey)!), [
      storedPreset,
      addedPreset.toMap(),
    ]);
  });

  test('keeps an update made while loading saved presets', () async {
    final storedPreset = {
      'id': 'stored',
      'name': 'Stored',
      'durationSeconds': 1.0,
      'direction': 'head',
    };
    final store = _DelayedInitializationStore.withData({
      'flutter.$presetKey': jsonEncode([storedPreset]),
    });
    SharedPreferencesStorePlatform.instance = store;

    final notifier = CustomTrimPresetsNotifier();
    final observedStates = <List<TrimPreset>>[];
    notifier.addListener(observedStates.add);
    final load = notifier.load();
    final update = notifier.update(
      'stored',
      TrimPreset(id: 'stored', name: 'Updated', durationSeconds: 3.0),
    );

    store.completeInitialization();
    await Future.wait([load, update]);

    expect(observedStates.last, hasLength(1));
    expect(observedStates.last.single.name, 'Updated');
  });

  test('keeps a removal made while loading saved presets', () async {
    final storedPreset = {
      'id': 'stored',
      'name': 'Stored',
      'durationSeconds': 1.0,
      'direction': 'head',
    };
    final otherPreset = {
      'id': 'other',
      'name': 'Other',
      'durationSeconds': 1.5,
      'direction': 'tail',
    };
    final store = _DelayedInitializationStore.withData({
      'flutter.$presetKey': jsonEncode([storedPreset, otherPreset]),
    });
    SharedPreferencesStorePlatform.instance = store;

    final notifier = CustomTrimPresetsNotifier();
    final observedStates = <List<TrimPreset>>[];
    notifier.addListener(observedStates.add);
    final load = notifier.load();
    final remove = notifier.remove('stored');

    store.completeInitialization();
    await Future.wait([load, remove]);

    expect(observedStates.last.map((preset) => preset.id), ['other']);
  });

  test('does not replay a listener mutation on a later load', () async {
    final storedPreset = {
      'id': 'stored',
      'name': 'Stored',
      'durationSeconds': 1.0,
      'direction': 'head',
    };
    final store = _DelayedInitializationStore.withData({
      'flutter.$presetKey': jsonEncode([storedPreset]),
    });
    SharedPreferencesStorePlatform.instance = store;

    final notifier = CustomTrimPresetsNotifier();
    final addedPreset = TrimPreset(
      id: 'listener-added',
      name: 'Listener added',
      durationSeconds: 2.0,
    );
    Future<void>? listenerAdd;
    var didTriggerAdd = false;
    notifier.addListener((presets) {
      if (presets.any((preset) => preset.id == 'stored') && !didTriggerAdd) {
        didTriggerAdd = true;
        listenerAdd = notifier.add(addedPreset);
      }
    });

    final load = notifier.load();
    store.completeInitialization();
    await load;
    await listenerAdd;
    await notifier.load();

    final observedStates = <List<TrimPreset>>[];
    notifier.addListener(observedStates.add);
    expect(observedStates.last.map((preset) => preset.id), [
      'stored',
      'listener-added',
    ]);
  });

  test('keeps a mutation when the pending load finds no saved value', () async {
    final store = _DelayedInitializationStore.withData({});
    SharedPreferencesStorePlatform.instance = store;

    final notifier = CustomTrimPresetsNotifier();
    final observedStates = <List<TrimPreset>>[];
    notifier.addListener(observedStates.add);
    final load = notifier.load();
    final addedPreset = TrimPreset(
      id: 'added',
      name: 'Added',
      durationSeconds: 2.0,
    );
    final add = notifier.add(addedPreset);

    store.completeInitialization();
    await Future.wait([load, add]);

    expect(observedStates.last.map((preset) => preset.id), ['added']);
  });
}
