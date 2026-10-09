import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import 'startup_preferences_io_stub.dart'
    if (dart.library.io) 'startup_preferences_io.dart'
    as startup_preferences_io;
import 'startup_preferences_web_stub.dart'
    if (dart.library.html) 'startup_preferences_web.dart'
    as startup_preferences_web;

/// A required startup preference could not be read or updated.
class StartupPreferencesUnavailable implements Exception {
  final Set<String> keys;
  final Object cause;

  const StartupPreferencesUnavailable(this.keys, this.cause);

  @override
  String toString() => 'Startup preferences unavailable for '
      '${keys.join(', ')}: $cause';
}

/// Reads individual preferences during startup without initializing the full
/// legacy preference cache.
class StartupPreferences {
  StartupPreferences._();

  // SharedPreferences' legacy API stores keys with this prefix. Async reads
  // address the platform store directly, so they must include it themselves.
  static const _legacyKeyPrefix = 'flutter.';
  static const _androidOptions = SharedPreferencesAsyncAndroidOptions(
    backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
    originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
      fileName: 'FlutterSharedPreferences',
    ),
  );

  static bool get _usesJsonFileBackend =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  static SharedPreferencesAsync _asyncPreferences() =>
      defaultTargetPlatform == TargetPlatform.android
          ? SharedPreferencesAsync(options: _androidOptions)
          : SharedPreferencesAsync();

  // Web retains its existing localStorage namespace. The browser only offers
  // synchronous localStorage reads, so request individual keys and leave all
  // large JSON parsing to the existing Web worker.

  /// Reads selected string keys. Linux and Windows store preferences in a JSON
  /// file; their current async plugin implementation still reads and decodes
  /// that file synchronously before filtering, so startup reads use an isolate
  /// and return only the requested entries.
  static Future<Map<String, String?>> getStrings(Iterable<String> keys) async {
    final logicalKeys = keys.toSet();
    if (logicalKeys.isEmpty) return const {};

    try {
      if (_isFlutterTest) {
        // Tests that use SharedPreferences.setMockInitialValues configure the
        // legacy in-memory store, not the async platform interface.
        final prefs = await SharedPreferences.getInstance();
        return {
          for (final key in logicalKeys) key: prefs.getString(key),
        };
      }

      final physicalKeys = {
        for (final key in logicalKeys) '$_legacyKeyPrefix$key',
      };
      final Map<String, Object?> physicalValues;
      if (_usesJsonFileBackend) {
        physicalValues = await startup_preferences_io.readValues(physicalKeys);
      } else {
        final preferences = _asyncPreferences();
        final entries = await Future.wait<MapEntry<String, Object?>>(
          logicalKeys.map(
            (key) async => MapEntry<String, Object?>(
              key,
              await preferences.getString('$_legacyKeyPrefix$key'),
            ),
          ),
        );
        physicalValues = Map.fromEntries(entries);
      }
      return {
        for (final key in logicalKeys)
          key: _stringValue(
            physicalValues,
            key,
            physicalKey: _usesJsonFileBackend ? '$_legacyKeyPrefix$key' : key,
          ),
      };
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(logicalKeys, error),
        stackTrace,
      );
    }
  }

  static String? _stringValue(
    Map<String, Object?> values,
    String key, {
    required String physicalKey,
  }) {
    final value = values[physicalKey];
    if (value != null && value is! String) {
      throw StartupPreferencesUnavailable(
        {key},
        FormatException('Expected a string preference for "$key".'),
      );
    }
    return value as String?;
  }

  static Future<String?> getString(String key) async =>
      (await getStrings([key]))[key];

  /// Reads selected values without initializing the legacy SharedPreferences
  /// cache. Used only to build a required pre-migration snapshot.
  static Future<Map<String, Object?>> getValues(Iterable<String> keys) async {
    final logicalKeys = keys.toSet();
    if (logicalKeys.isEmpty) return const {};

    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        return {
          for (final key in logicalKeys)
            if (prefs.containsKey(key)) key: prefs.get(key),
        };
      }

      final physicalKeys = {
        for (final key in logicalKeys) '$_legacyKeyPrefix$key',
      };
      if (_usesJsonFileBackend) {
        final physicalValues =
            await startup_preferences_io.readValues(physicalKeys);
        return {
          for (final key in logicalKeys)
            if (physicalValues.containsKey('$_legacyKeyPrefix$key'))
              key: physicalValues['$_legacyKeyPrefix$key']!,
        };
      }

      final preferences = _asyncPreferences();
      final entries = await Future.wait<MapEntry<String, Object?>>(
        logicalKeys.map(
          (key) async => MapEntry<String, Object?>(
            key,
            await _readAsyncValue(
              preferences,
              '$_legacyKeyPrefix$key',
            ),
          ),
        ),
      );
      return {
        for (final entry in entries)
          if (entry.value != null) entry.key: entry.value!,
      };
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(logicalKeys, error),
        stackTrace,
      );
    }
  }

  static Future<Object?> _readAsyncValue(
    SharedPreferencesAsync preferences,
    String key,
  ) async {
    try {
      final value = await preferences.getString(key);
      if (value != null) return value;
    } on TypeError {
      // Continue with the other supported preference types.
    }
    try {
      final value = await preferences.getBool(key);
      if (value != null) return value;
    } on TypeError {
      // Continue with the other supported preference types.
    }
    try {
      final value = await preferences.getInt(key);
      if (value != null) return value;
    } on TypeError {
      // Continue with the other supported preference types.
    }
    try {
      final value = await preferences.getDouble(key);
      if (value != null) return value;
    } on TypeError {
      // Continue with the other supported preference types.
    }
    try {
      final value = await preferences.getStringList(key);
      if (value != null) return value;
    } on TypeError {
      // Continue with the other supported preference types.
    }

    if (await preferences.containsKey(key)) {
      throw FormatException('Unsupported preference value for "$key".');
    }
    return null;
  }

  static Future<bool?> getBool(String key) async {
    try {
      if (_isFlutterTest) {
        return (await SharedPreferences.getInstance()).getBool(key);
      }
      final physicalKey = '$_legacyKeyPrefix$key';
      final physicalValues = _usesJsonFileBackend
          ? await startup_preferences_io.readValues({physicalKey})
          : {physicalKey: await _asyncPreferences().getBool(physicalKey)};
      final value = physicalValues[physicalKey];
      if (value != null && value is! bool) {
        throw StartupPreferencesUnavailable(
          {key},
          FormatException('Expected a bool preference for "$key".'),
        );
      }
      return value as bool?;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<bool> containsKey(String key) async {
    try {
      if (_isFlutterTest) {
        return (await SharedPreferences.getInstance()).containsKey(key);
      }
      final physicalKey = '$_legacyKeyPrefix$key';
      if (_usesJsonFileBackend) {
        return (await startup_preferences_io.readValues({physicalKey}))
            .containsKey(physicalKey);
      }
      return await _asyncPreferences().containsKey(physicalKey);
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<Set<String>> getKeys() async {
    try {
      if (_isFlutterTest) {
        return (await SharedPreferences.getInstance()).getKeys();
      }
      if (_usesJsonFileBackend) {
        final keys = await startup_preferences_io.readKeys();
        return {
          for (final key in keys)
            if (key.startsWith(_legacyKeyPrefix))
              key.substring(_legacyKeyPrefix.length),
        };
      }
      final physicalKeys = kIsWeb
          ? startup_preferences_web.getLegacyPreferenceKeys()
          : await _asyncPreferences().getKeys();
      return {
        for (final key in physicalKeys)
          if (key.startsWith(_legacyKeyPrefix))
            key.substring(_legacyKeyPrefix.length),
      };
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(const {}, error),
        stackTrace,
      );
    }
  }

  static Future<int?> getInt(String key) async {
    try {
      if (_isFlutterTest) {
        return (await SharedPreferences.getInstance()).getInt(key);
      }
      final physicalKey = '$_legacyKeyPrefix$key';
      final physicalValues = _usesJsonFileBackend
          ? await startup_preferences_io.readValues({physicalKey})
          : {physicalKey: await _asyncPreferences().getInt(physicalKey)};
      final value = physicalValues[physicalKey];
      if (value != null && value is! int) {
        throw StartupPreferencesUnavailable(
          {key},
          FormatException('Expected an int preference for "$key".'),
        );
      }
      return value as int?;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> setString(String key, String value) async {
    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        final updated = await prefs.setString(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.writeValue('$_legacyKeyPrefix$key', value);
      } else {
        await _asyncPreferences().setString('$_legacyKeyPrefix$key', value);
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> setBool(String key, bool value) async {
    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        final updated = await prefs.setBool(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.writeValue('$_legacyKeyPrefix$key', value);
      } else {
        await _asyncPreferences().setBool('$_legacyKeyPrefix$key', value);
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> setInt(String key, int value) async {
    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        final updated = await prefs.setInt(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.writeValue('$_legacyKeyPrefix$key', value);
      } else {
        await _asyncPreferences().setInt('$_legacyKeyPrefix$key', value);
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> setDouble(String key, double value) async {
    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        final updated = await prefs.setDouble(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.writeValue('$_legacyKeyPrefix$key', value);
      } else {
        await _asyncPreferences().setDouble('$_legacyKeyPrefix$key', value);
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> setStringList(String key, List<String> value) async {
    try {
      if (_isFlutterTest) {
        final prefs = await SharedPreferences.getInstance();
        final updated = await prefs.setStringList(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.writeValue('$_legacyKeyPrefix$key', value);
      } else {
        await _asyncPreferences().setStringList('$_legacyKeyPrefix$key', value);
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  static Future<void> remove(String key) async {
    try {
      if (_isFlutterTest) {
        await (await SharedPreferences.getInstance()).remove(key);
      } else if (_usesJsonFileBackend) {
        await startup_preferences_io.removeValue('$_legacyKeyPrefix$key');
      } else {
        await _asyncPreferences().remove('$_legacyKeyPrefix$key');
      }
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }
}

/// Preference adapter used by legacy migration and version-record updates.
/// Production platforms use targeted key operations; Linux and Windows read
/// selected values through their JSON-file isolate adapter.
class StartupMigrationPreferences {
  StartupMigrationPreferences._({
    SharedPreferences? legacyPreferences,
  }) : _legacyPreferences = legacyPreferences;

  final SharedPreferences? _legacyPreferences;

  static StartupMigrationPreferences forLegacyPreferences(
    SharedPreferences preferences,
  ) =>
      StartupMigrationPreferences._(legacyPreferences: preferences);

  static Future<StartupMigrationPreferences> load() async {
    try {
      if (StartupPreferences._isFlutterTest) {
        return StartupMigrationPreferences._(
          legacyPreferences: await SharedPreferences.getInstance(),
        );
      }
      return StartupMigrationPreferences._();
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(const {}, error),
        stackTrace,
      );
    }
  }

  Future<Set<String>> getKeys() async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) return legacyPreferences.getKeys();
      return StartupPreferences.getKeys();
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(const {}, error),
        stackTrace,
      );
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      final legacyPreferences = _legacyPreferences;
      return legacyPreferences != null
          ? legacyPreferences.containsKey(key)
          : StartupPreferences.containsKey(key);
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<String?> getString(String key) async {
    try {
      final legacyPreferences = _legacyPreferences;
      return legacyPreferences != null
          ? legacyPreferences.getString(key)
          : StartupPreferences.getString(key);
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<int?> getInt(String key) async {
    try {
      final legacyPreferences = _legacyPreferences;
      return legacyPreferences != null
          ? legacyPreferences.getInt(key)
          : StartupPreferences.getInt(key);
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> setString(String key, String value) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final updated = await legacyPreferences.setString(key, value);
        if (!updated) {
          throw StateError('Failed to write preference "$key".');
        }
      } else {
        await StartupPreferences.setString(key, value);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> setBool(String key, bool value) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final updated = await legacyPreferences.setBool(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else {
        await StartupPreferences.setBool(key, value);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> setInt(String key, int value) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final updated = await legacyPreferences.setInt(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else {
        await StartupPreferences.setInt(key, value);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> setDouble(String key, double value) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final updated = await legacyPreferences.setDouble(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else {
        await StartupPreferences.setDouble(key, value);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> setStringList(String key, List<String> value) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final updated = await legacyPreferences.setStringList(key, value);
        if (!updated) throw StateError('Failed to write preference "$key".');
      } else {
        await StartupPreferences.setStringList(key, value);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }

  Future<bool> remove(String key) async {
    try {
      final legacyPreferences = _legacyPreferences;
      if (legacyPreferences != null) {
        final removed = await legacyPreferences.remove(key);
        if (!removed) {
          throw StateError('Failed to remove preference "$key".');
        }
      } else {
        await StartupPreferences.remove(key);
      }
      return true;
    } catch (error, stackTrace) {
      if (error is StartupPreferencesUnavailable) rethrow;
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable({key}, error),
        stackTrace,
      );
    }
  }
}
