// The analyzer does not recognize this repository's `tests/` root as a test
// directory for this `@visibleForTesting` hook.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, kIsWeb, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:stroom/services/startup_preferences.dart';
import 'package:stroom/services/startup_preferences_web.dart'
    as startup_preferences_web;

// The neighboring symlinks expose the tracked suite and worker asset to the
// Flutter Web test server.
import 'startup_check_service_test_source.dart' as checks;

void main() {
  StartupPreferences.debugUseLegacyPreferencesForTesting = true;
  checks.loadStartupValidationWorkerSourceForTesting = () =>
      html.HttpRequest.getString(
        Uri.base.resolve('/startup/data_integrity_json_worker.js').toString(),
      );
  checks.main();

  test(
    'startup preferences use Web defaults and the legacy storage namespace',
    () async {
      const key = 'startup_preferences_web_import_regression';
      const storageKey = 'flutter.$key';
      const value = 'saved on web';
      final storage = html.window.localStorage;
      final previousPlatform = debugDefaultTargetPlatformOverride;
      final previousAsyncPreferences = SharedPreferencesAsyncPlatform.instance;
      final asyncPreferences = _RecordingAsyncPreferences(storage);
      StartupPreferences.debugUseLegacyPreferencesForTesting = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferencesAsyncPlatform.instance = asyncPreferences;
      storage.remove(storageKey);
      storage[storageKey] = 'stored web value';

      addTearDown(() {
        storage.remove(storageKey);
        StartupPreferences.debugUseLegacyPreferencesForTesting = true;
        debugDefaultTargetPlatformOverride = previousPlatform;
        SharedPreferencesAsyncPlatform.instance = previousAsyncPreferences;
      });

      expect(kIsWeb, isTrue);
      await StartupPreferences.setString(key, value);

      expect(asyncPreferences.lastKey, storageKey);
      expect(
        asyncPreferences.lastOptions.runtimeType,
        SharedPreferencesOptions,
      );
      expect(storage[storageKey], jsonEncode(value));
      expect(await StartupPreferences.getString(key), value);
      expect(startup_preferences_web.getLegacyPreferenceKeys(), contains(key));

      await StartupPreferences.remove(key);
      expect(storage[storageKey], isNull);
    },
  );
}

final class _RecordingAsyncPreferences extends InMemorySharedPreferencesAsync {
  _RecordingAsyncPreferences(this._storage) : super.empty();

  final html.Storage _storage;

  SharedPreferencesOptions? lastOptions;
  String? lastKey;

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) {
    lastKey = key;
    lastOptions = options;
    _storage[key] = jsonEncode(value);
    return Future.value(true);
  }

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    lastKey = key;
    lastOptions = options;
    final value = _storage[key];
    return Future.value(value == null ? null : jsonDecode(value) as String);
  }

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) {
    final keys = parameters.filter.allowList;
    if (keys != null) {
      for (final key in keys) {
        _storage.remove(key);
      }
    }
    return Future.value(true);
  }
}
