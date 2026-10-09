import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _preferencesFileName = 'shared_preferences.json';

/// Reads selected values from the same JSON file used by the Linux and
/// Windows shared_preferences implementations.
Future<Map<String, Object?>> readValues(Set<String> keys) async {
  final directory = await getApplicationSupportDirectory();
  final filePath = p.join(directory.path, _preferencesFileName);
  return Isolate.run(() => _readValuesFromFile(filePath, keys.toList()));
}

/// Loads every legacy preference for a real migration. The file read and JSON
/// decode both happen in the worker isolate.
Future<Map<String, Object?>> readAllValues() async {
  final directory = await getApplicationSupportDirectory();
  final filePath = p.join(directory.path, _preferencesFileName);
  return Isolate.run(() => _readAllValuesFromFile(filePath));
}

/// Writes one legacy preference without decoding the file on the UI isolate.
Future<void> writeValue(String key, Object value) async {
  final directory = await getApplicationSupportDirectory();
  final filePath = p.join(directory.path, _preferencesFileName);
  await Isolate.run(() => _writeValueToFile(filePath, key, value));
}

/// Removes one key while preserving every other legacy preference.
Future<void> removeValue(String key) async {
  final directory = await getApplicationSupportDirectory();
  final filePath = p.join(directory.path, _preferencesFileName);
  await Isolate.run(() => _removeValueFromFile(filePath, key));
}

Future<Map<String, Object?>> _readValuesFromFile(
  String filePath,
  List<String> requestedKeys,
) async {
  final preferences = await _readAllValuesFromFile(filePath);
  return {
    for (final key in requestedKeys)
      if (preferences.containsKey(key)) key: preferences[key],
  };
}

Future<Map<String, Object?>> _readAllValuesFromFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return const {};

  final content = await file.readAsString();
  if (content.isEmpty) return const {};

  final decoded = jsonDecode(content);
  if (decoded is! Map) {
    throw const FormatException(
      'Expected the shared preferences file to contain a JSON object.',
    );
  }

  return Map<String, Object?>.from(decoded);
}

Future<void> _writeValueToFile(
  String filePath,
  String key,
  Object value,
) async {
  final file = File(filePath);
  final preferences = await _readAllValuesFromFile(filePath);
  preferences[key] = value;
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(preferences));
}

Future<void> _removeValueFromFile(String filePath, String key) async {
  final file = File(filePath);
  if (!await file.exists()) return;
  final preferences = await _readAllValuesFromFile(filePath);
  if (!preferences.containsKey(key)) return;

  preferences.remove(key);
  await file.writeAsString(jsonEncode(preferences));
}
