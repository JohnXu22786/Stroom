import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'data_integrity_json_parser.dart' as json_parser;
import 'data_migration_isolate_stub.dart'
    if (dart.library.io) 'data_migration_isolate_io.dart'
    as data_migration_isolate;
import 'startup_data_validation_unavailable.dart';
import 'startup_preferences.dart';
import 'storage_service.dart';

/// Startup-only migration. Runtime model selection never reads legacy indices.
class ProviderModelMigration {
  static Future<void> migrateSettings([
    StartupMigrationPreferences? prefs,
  ]) async {
    prefs ??= await StartupMigrationPreferences.load();
    final encoded = await prefs.getString('provider_entries');
    if (encoded == null || encoded.isEmpty) return;
    final Map<String, Object?> migrated;
    if (kIsWeb) {
      migrated = await json_parser.migrateProviderModelSettingsWeb(encoded);
    } else if (_isFlutterTest) {
      migrated = _migrateSettingsSync(encoded);
    } else {
      try {
        migrated = await data_migration_isolate.runInIsolate(
          () => _migrateSettingsSync(encoded),
        );
      } catch (error) {
        throw StartupDataValidationUnavailable.isolate(error);
      }
    }
    if (migrated['status'] == 'parseError') {
      throw FormatException('${migrated['error']}');
    }
    if (migrated['status'] != 'ok') {
      throw StartupDataValidationUnavailable.isolate(
        StateError('Invalid provider model migration result.'),
      );
    }
    if (migrated['changed'] != true) return;
    final updated = migrated['payload'];
    if (updated is! String) {
      throw StartupDataValidationUnavailable.isolate(
        StateError('Missing migrated provider model settings.'),
      );
    }
    if (!await prefs.setString('provider_entries', updated) ||
        await prefs.getString('provider_entries') != updated) {
      throw StateError('无法保存供应商与模型身份');
    }
  }

  static Map<String, Object?> _migrateSettingsSync(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } catch (error) {
      return {'status': 'parseError', 'error': error.toString()};
    }
    if (decoded is! List) {
      return {'status': 'parseError', 'error': 'Expected a list.'};
    }

    final configs = <Map>[];
    final models = <Map>[];
    for (final entry in decoded.whereType<Map>()) {
      // Before configs[] existed, a provider entry held a single config.
      // Normalize that shape before assigning IDs, so loading it cannot create
      // a fresh identity on every restart.
      if (!entry.containsKey('configs')) {
        const fields = [
          'providerName',
          'host',
          'key',
          'models',
          'typeConfig',
          'customParams',
          'reasoningParams',
          'endpointType'
        ];
        final config = <String, dynamic>{
          for (final field in fields)
            if (entry.containsKey(field)) field: entry[field],
        };
        entry['configs'] = ['providerName', 'host', 'key'].any((key) =>
                (config[key] is String) && (config[key] as String).isNotEmpty)
            ? [config]
            : <Map>[];
        for (final field in fields) {
          entry.remove(field);
        }
      }
      for (final config
          in (entry['configs'] is List ? entry['configs'] as List : const [])
              .whereType<Map>()) {
        configs.add(config);
        models.addAll(
            (config['models'] is List ? config['models'] as List : const [])
                .whereType<Map>());
      }
    }
    final configIdsChanged = _assignIds(configs, 'config');
    final modelIdsChanged = _assignIds(models, 'model');
    final updated = jsonEncode(decoded);
    final changed = configIdsChanged || modelIdsChanged || updated != encoded;
    if (!changed) return {'status': 'ok', 'changed': false};
    return {
      'status': 'ok',
      'changed': true,
      'payload': updated,
    };
  }

  static bool get _isFlutterTest {
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  static bool _assignIds(List<Map> items, String prefix) {
    final counts = <String, int>{};
    for (final item in items) {
      final id = item['id'];
      if (id is String && id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
    }
    var changed = false;
    for (final item in items) {
      final id = item['id'];
      // Duplicate IDs are all replaced: retaining the first would silently
      // redirect an existing reference to an arbitrary duplicate.
      if (id is! String || id.isEmpty || counts[id] != 1) {
        item['id'] = '${prefix}_${const Uuid().v4()}';
        changed = true;
      }
    }
    return changed;
  }

  static Future<void> migrateFlows() async {
    // Flow persistence is native-only (PersistableNotifier). The memory
    // backend used by backup tests must not read or rewrite native user data.
    if (kIsWeb || WebFileStore.isTestMode) return;
    final directory = await AppStorage.directory;
    final file = File('$directory/task_flows/flows.json');
    if (!await file.exists()) return;
    final encoded = await file.readAsString();
    if (encoded.isEmpty) return;
    final Map<String, Object?> result;
    try {
      result = _isFlutterTest
          ? _migrateFlowsSync(encoded)
          : await data_migration_isolate.runInIsolate(
              () => _migrateFlowsSync(encoded),
            );
    } catch (error, stackTrace) {
      if (_isFlutterTest) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      throw StartupDataValidationUnavailable.isolate(error);
    }
    if (result['changed'] != true) return;
    final updated = result['updated'] as String;
    await AtomicFile.writeString(file, updated);
    final fileMatches = _isFlutterTest
        ? await _fileMatchesContent(file.path, updated)
        : await data_migration_isolate.runInIsolate(
            () => _fileMatchesContent(file.path, updated),
          );
    if (!fileMatches) {
      throw StateError('任务流模型引用迁移校验失败');
    }
  }

  static Map<String, Object?> _migrateFlowsSync(String encoded) {
    final flows = jsonDecode(encoded) as List;
    for (final flow in flows.whereType<Map>()) {
      for (final block in (flow['blocks'] as List? ?? []).whereType<Map>()) {
        if (!['asr', 'ocr', 'tts'].contains(block['typeKey'])) continue;
        final params = Map<String, dynamic>.from(block['params'] as Map? ?? {});
        params.remove('modelIndex');
        if (params['modelRef'] == null) {
          // An index alone cannot prove which model was originally selected:
          // an earlier deletion/reorder may already have changed its meaning.
          params['modelRef'] = null;
          params['modelSelectionRequired'] = true;
        }
        block['params'] = params;
      }
    }
    final updated = jsonEncode(flows);
    if (updated == encoded) return {'changed': false};
    return {'changed': true, 'updated': updated};
  }
}

Future<bool> _fileMatchesContent(String path, String content) async =>
    await File(path).readAsString() == content;
