// ignore_for_file: invalid_use_of_visible_for_testing_member, use_super_parameters

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
