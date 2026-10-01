import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/atomic_file.dart';
import 'storage_service.dart';

/// Startup-only migration. Runtime model selection never reads legacy indices.
class ProviderModelMigration {
  static Future<void> migrateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('provider_entries');
    if (encoded == null || encoded.isEmpty) return;
    final entries = jsonDecode(encoded) as List;
    final configs = <Map>[];
    final models = <Map>[];
    for (final entry in entries.whereType<Map>()) {
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
    _assignIds(configs, 'config');
    _assignIds(models, 'model');
    final updated = jsonEncode(entries);
    if (updated == encoded) return;
    if (!await prefs.setString('provider_entries', updated) ||
        prefs.getString('provider_entries') != updated) {
      throw StateError('无法保存供应商与模型身份');
    }
  }

  static void _assignIds(List<Map> items, String prefix) {
    final counts = <String, int>{};
    for (final item in items) {
      final id = item['id'];
      if (id is String && id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final item in items) {
      final id = item['id'];
      // Duplicate IDs are all replaced: retaining the first would silently
      // redirect an existing reference to an arbitrary duplicate.
      if (id is! String || id.isEmpty || counts[id] != 1) {
        item['id'] = '${prefix}_${const Uuid().v4()}';
      }
    }
  }

  static Future<void> migrateFlows() async {
    // Flow persistence is currently native-only (PersistableNotifier).
    if (kIsWeb) return;
    final directory = await AppStorage.directory;
    final file = File('$directory/task_flows/flows.json');
    if (!await file.exists()) return;
    final encoded = await file.readAsString();
    if (encoded.isEmpty) return;
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
    if (updated == encoded) return;
    await AtomicFile.writeString(file, updated);
    if (await file.readAsString() != updated) {
      throw StateError('任务流模型引用迁移校验失败');
    }
  }
}
