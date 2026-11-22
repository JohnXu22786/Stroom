part of 'data_migration_service.dart';

/// 损坏备份上限（对齐 provider_config_persistence 的约定）。
const int _kMaxCorruptBackups = 3;

/// 隔离损坏数据：写入带时间戳的 key（如 `provider_entries_corrupt_123`），
/// 只保留最近 [_kMaxCorruptBackups] 份。
///
/// 使用时间戳而非固定 key：固定 key 会被下一次隔离事件覆盖，丢失
/// 前一份损坏证据（例如备份恢复重新引入损坏数据时）。
Future<void> _quarantineCorruptData(
  StartupMigrationPreferences prefs,
  String keyPrefix,
  String corruptJson,
) async {
  try {
    final backupKey =
        '${keyPrefix}_corrupt_${DateTime.now().millisecondsSinceEpoch}';
    if (!await prefs.setString(backupKey, corruptJson) ||
        await prefs.getString(backupKey) != corruptJson) {
      throw StateError('Unable to verify quarantined $keyPrefix data.');
    }
    // 只保留最近的 N 份
    final keys = (await prefs.getKeys()).toList()
      ..sort()
      ..retainWhere((k) => k.startsWith('${keyPrefix}_corrupt_'));
    while (keys.length > _kMaxCorruptBackups) {
      final key = keys.removeAt(0);
      await prefs.remove(key);
      if (await prefs.containsKey(key)) {
        throw StateError('Unable to prune quarantined $keyPrefix data.');
      }
    }
    debugPrint('[DataMigrationService] 已隔离损坏数据到 $backupKey');
  } catch (error, stackTrace) {
    if (error is StartupPreferencesUnavailable ||
        error is StartupDataValidationUnavailable) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    Error.throwWithStackTrace(
      StartupDataValidationUnavailable.migration(error),
      stackTrace,
    );
  }
}

Future<void> _removeMigratedPreference(
  StartupMigrationPreferences prefs,
  String key,
) async {
  try {
    await prefs.remove(key);
    if (await prefs.containsKey(key)) {
      throw StateError('Unable to remove migrated preference "$key".');
    }
  } catch (error, stackTrace) {
    if (error is StartupPreferencesUnavailable ||
        error is StartupDataValidationUnavailable) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    Error.throwWithStackTrace(
      StartupDataValidationUnavailable.migration(error),
      stackTrace,
    );
  }
}

Future<void> _writeMigratedPreference(
  StartupMigrationPreferences prefs,
  String key,
  String value,
) async {
  try {
    if (!await prefs.setString(key, value) ||
        await prefs.getString(key) != value) {
      throw StateError('Unable to verify migrated preference "$key".');
    }
  } catch (error, stackTrace) {
    if (error is StartupPreferencesUnavailable ||
        error is StartupDataValidationUnavailable) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    Error.throwWithStackTrace(
      StartupDataValidationUnavailable.migration(error),
      stackTrace,
    );
  }
}

// ====================================================================
// 旧配置迁移（v0→v1 相关，从 DataMigrationService 拆出控制行数）
// ====================================================================

/// 旧 chat_configs 迁移辅助（同库可见，外部仍通过
/// DataMigrationService 的私有静态委托调用）。
class DataMigrationOldConfigs {
  static StartupMigrationPreferences _migrationPreferences(Object preferences) {
    if (preferences is StartupMigrationPreferences) return preferences;
    if (preferences is SharedPreferences) {
      return StartupMigrationPreferences.forLegacyPreferences(preferences);
    }
    throw ArgumentError.value(
      preferences,
      'preferences',
      'Expected a startup migration preference adapter.',
    );
  }

  /// 迁移旧版 chat_configs（被重构删除的格式）到 provider_entries。
  static Future<void> migrateOldChatConfigs(Object preferences) async {
    final prefs = _migrationPreferences(preferences);
    final oldJson = await prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      final prepared = await _prepareLegacyChatConfigs(oldJson);
      final status = prepared['status'];
      if (status == 'parseError') {
        debugPrint(
          '[DataMigrationService] Failed to migrate old chat configs: '
          '${prepared['error']}',
        );
        await _quarantineCorruptData(prefs, 'chat_configs', oldJson);
        await _removeMigratedPreference(prefs, 'chat_selected_config_id');
        await _removeMigratedPreference(prefs, 'chat_configs');
        return;
      }
      if (status == 'notList') {
        debugPrint(
          '[DataMigrationService] chat_configs 不是合法数组，'
          '隔离后清理旧配置',
        );
        await _quarantineCorruptData(prefs, 'chat_configs', oldJson);
        await _removeMigratedPreference(prefs, 'chat_selected_config_id');
        await _removeMigratedPreference(prefs, 'chat_configs');
        return;
      }
      if (status == 'empty') {
        await _removeMigratedPreference(prefs, 'chat_selected_config_id');
        await _removeMigratedPreference(prefs, 'chat_configs');
        return;
      }
      if (status != 'ready' || prepared['payload'] is! String) {
        throw StartupDataValidationUnavailable.isolate(
          StateError('Invalid legacy chat config migration result.'),
        );
      }

      String? existingJson;
      try {
        existingJson = await prefs.getString('provider_entries');
      } catch (error) {
        if (error is StartupPreferencesUnavailable) rethrow;
      }

      final merged = await _mergeLegacyChatConfigs(
        prepared['payload']! as String,
        existingJson,
      );
      if (merged['corruptExisting'] == true) {
        debugPrint(
          '[DataMigrationService] 现有 provider_entries 不是'
          '合法数组，开始隔离',
        );
        await _quarantineCorruptData(prefs, 'provider_entries', existingJson!);
      }
      if (merged['status'] == 'write') {
        final payload = merged['payload'];
        if (payload is! String) {
          throw StartupDataValidationUnavailable.isolate(
            StateError('Missing migrated provider entries.'),
          );
        }
        await _writeMigratedPreference(prefs, 'provider_entries', payload);
        debugPrint(
          '[DataMigrationService] Migrated ${prepared['legacyConfigCount']} old chat config(s) to provider_entries',
        );
      } else if (merged['status'] != 'alreadyMigrated') {
        throw StartupDataValidationUnavailable.isolate(
          StateError('Invalid legacy chat config merge result.'),
        );
      }

      await _removeMigratedPreference(prefs, 'chat_selected_config_id');
      await _removeMigratedPreference(prefs, 'chat_configs');
    } catch (error, stackTrace) {
      debugPrint(
        '[DataMigrationService] Failed to migrate old chat configs: $error',
      );
      if (error is StartupPreferencesUnavailable ||
          error is StartupDataValidationUnavailable) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(
        StartupDataValidationUnavailable.migration(error),
        stackTrace,
      );
    }
  }

  /// 修复 provider_entries 中所有条目的 id 字段不为空。
  ///
  /// 旧版数据中某些条目的 id 可能为 null，导致 ProviderEntry.fromMap()
  /// 在 `map['id'] as String` 处抛出 TypeError，进而引发闪退。
  static Future<void> fixNullIdsInProviderEntries(Object preferences) async {
    final prefs = _migrationPreferences(preferences);
    final json = await prefs.getString('provider_entries');
    if (json == null || json.isEmpty) return;

    try {
      final migrated = await _fixProviderEntries(json);
      if (migrated['status'] == 'parseError') {
        debugPrint(
          '[DataMigrationService] Failed to fix provider entries: '
          '${migrated['error']}',
        );
        await _quarantineCorruptData(prefs, 'provider_entries', json);
        await _writeMigratedPreference(prefs, 'provider_entries', '[]');
        return;
      }
      if (migrated['status'] == 'notList') {
        debugPrint(
          '[DataMigrationService] provider_entries 不是合法数组，'
          '已隔离并重置为空列表',
        );
        await _quarantineCorruptData(prefs, 'provider_entries', json);
        await _writeMigratedPreference(prefs, 'provider_entries', '[]');
        return;
      }
      if (migrated['status'] != 'ok') {
        throw StartupDataValidationUnavailable.isolate(
          StateError('Invalid provider entry migration result.'),
        );
      }
      if (migrated['changed'] == true) {
        final payload = migrated['payload'];
        if (payload is! String) {
          throw StartupDataValidationUnavailable.isolate(
            StateError('Missing migrated provider entries.'),
          );
        }
        await _writeMigratedPreference(prefs, 'provider_entries', payload);
        debugPrint(
          '[DataMigrationService] Fixed null IDs/types in provider_entries',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[DataMigrationService] Failed to fix provider entries: '
        '$error',
      );
      if (error is StartupPreferencesUnavailable ||
          error is StartupDataValidationUnavailable) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(
        StartupDataValidationUnavailable.migration(error),
        stackTrace,
      );
    }
  }

  static Future<Map<String, Object?>> _prepareLegacyChatConfigs(
    String raw,
  ) async {
    if (kIsWeb) return json_parser.prepareLegacyChatConfigsWeb(raw);
    if (_isFlutterTest) return _prepareLegacyChatConfigsSync(raw);
    try {
      return await data_migration_isolate.runInIsolate(
        () => _prepareLegacyChatConfigsSync(raw),
      );
    } catch (error) {
      throw StartupDataValidationUnavailable.isolate(error);
    }
  }

  static Future<Map<String, Object?>> _mergeLegacyChatConfigs(
    String migratedConfigs,
    String? existingEntries,
  ) async {
    if (kIsWeb) {
      return json_parser.mergeLegacyChatConfigsWeb(
        migratedConfigs,
        existingEntries,
      );
    }
    if (_isFlutterTest) {
      return _mergeLegacyChatConfigsSync(migratedConfigs, existingEntries);
    }
    try {
      return await data_migration_isolate.runInIsolate(
        () => _mergeLegacyChatConfigsSync(migratedConfigs, existingEntries),
      );
    } catch (error) {
      throw StartupDataValidationUnavailable.isolate(error);
    }
  }

  static Future<Map<String, Object?>> _fixProviderEntries(String raw) async {
    if (kIsWeb) return json_parser.fixProviderEntriesWeb(raw);
    if (_isFlutterTest) return _fixProviderEntriesSync(raw);
    try {
      return await data_migration_isolate.runInIsolate(
        () => _fixProviderEntriesSync(raw),
      );
    } catch (error) {
      throw StartupDataValidationUnavailable.isolate(error);
    }
  }
}

Map<String, Object?> _prepareLegacyChatConfigsSync(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (error) {
    return {'status': 'parseError', 'error': error.toString()};
  }
  if (decoded is! List) return {'status': 'notList'};

  final oldList = decoded.whereType<Map<String, dynamic>>().toList();
  if (oldList.isEmpty) return {'status': 'empty'};

  final migratedConfigs = <Map<String, dynamic>>[];
  for (final oldItem in oldList) {
    final rawModels = oldItem['models'];
    final oldModels = rawModels is List
        ? rawModels.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final models = oldModels.map((model) {
      final typeConfig = model['typeConfig'] is Map
          ? Map<String, dynamic>.from(model['typeConfig'] as Map)
          : <String, dynamic>{};
      final temperature = model['temperature'];
      if (temperature != null) typeConfig['temperature'] = temperature;
      final context = model['maxTokens'] ?? model['context'];
      if (context != null) typeConfig['context'] = context;
      final modelId = model['modelId'];
      final modelName = model['name'];
      final stableModelId = modelId is String && modelId.trim().isNotEmpty
          ? modelId
          : (modelName is String && modelName.trim().isNotEmpty
              ? modelName
              : '');
      return <String, dynamic>{
        'name': modelName is String && modelName.trim().isNotEmpty
            ? modelName
            : stableModelId,
        'modelId': stableModelId,
        'supportStream': model['supportStream'] is bool
            ? model['supportStream'] as bool
            : true,
        'typeConfig': typeConfig,
      };
    }).toList();
    final migratedConfig = <String, dynamic>{
      'providerName':
          oldItem['providerName'] is String ? oldItem['providerName'] : '',
      'host': oldItem['host'] is String ? oldItem['host'] : '',
      'key': oldItem['key'] is String ? oldItem['key'] : '',
      'models': models,
    };
    for (final field in const ['credentialRef', 'publicKey']) {
      final value = oldItem[field];
      if (value != null) {
        if (value is! String || value.trim().isEmpty) {
          throw const FormatException('Invalid safe legacy metadata.');
        }
        migratedConfig[field] = value;
      }
    }
    migratedConfigs.add(migratedConfig);
  }

  return {
    'status': 'ready',
    'legacyConfigCount': oldList.length,
    'payload': jsonEncode(migratedConfigs),
  };
}

Map<String, Object?> _mergeLegacyChatConfigsSync(
  String migratedConfigsJson,
  String? existingJson,
) {
  final decodedMigratedConfigs = jsonDecode(migratedConfigsJson) as List;
  final migratedConfigs = <Map<String, dynamic>>[];
  final migratedIdentities = <String>{};
  for (final config
      in decodedMigratedConfigs.whereType<Map<String, dynamic>>()) {
    if (migratedIdentities.add(_legacyChatConfigIdentity(config))) {
      migratedConfigs.add(config);
    }
  }

  List<Map<String, dynamic>> existingEntries = [];
  var corruptExisting = false;
  if (existingJson != null && existingJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(existingJson);
      if (decoded is! List) {
        corruptExisting = true;
      } else {
        existingEntries = decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {
      corruptExisting = true;
    }
  }

  for (var i = 0; i < migratedConfigs.length; i++) {
    for (var j = i + 1; j < migratedConfigs.length; j++) {
      final first = migratedConfigs[i];
      final second = migratedConfigs[j];
      if (_sameLegacyProviderConfig(first, second) &&
          _mergeLegacySafeMetadata(Map<String, dynamic>.from(first), second) ==
              null) {
        return {'status': 'conflict', 'corruptExisting': corruptExisting};
      }
    }
  }
  for (final entry in existingEntries.where(
    (entry) => entry['type'] == 'llm' && entry['id'] != 'builtin_llm',
  )) {
    final rawConfigs = entry['configs'];
    final hasTopLevelConfig = entry.keys.any(
      (key) =>
          key != 'configs' &&
          !const {'id', 'type', 'name', 'enabled'}.contains(key),
    );
    if (rawConfigs is! List && (rawConfigs != null || hasTopLevelConfig)) {
      final prepared = _prepareLegacyChatConfigsSync(jsonEncode([entry]));
      final topLevelConfigs = prepared['payload'] is String
          ? (jsonDecode(prepared['payload']! as String) as List)
              .whereType<Map<String, dynamic>>()
          : const <Map<String, dynamic>>[];
      if (migratedConfigs.any(
        (legacy) => !topLevelConfigs.any(
          (topLevel) => _sameLegacyProviderConfig(topLevel, legacy),
        ),
      )) {
        return {'status': 'conflict', 'corruptExisting': corruptExisting};
      }
    }
    if (rawConfigs is! List) continue;
    for (final rawConfig in rawConfigs.whereType<Map>()) {
      final existingConfig = Map<String, dynamic>.from(rawConfig);
      for (final legacyConfig in migratedConfigs) {
        if (_sameLegacyProviderConfig(existingConfig, legacyConfig) &&
            _mergeLegacySafeMetadata(
                  Map<String, dynamic>.from(existingConfig),
                  legacyConfig,
                ) ==
                null) {
          return {'status': 'conflict', 'corruptExisting': corruptExisting};
        }
      }
    }
  }

  final usableLlmEntryIndex = existingEntries.indexWhere((entry) {
    if (entry['type'] != 'llm' || entry['id'] == 'builtin_llm') return false;
    try {
      final parsed = ProviderEntry.fromMap(entry);
      if (parsed.configs.isEmpty) return false;
      jsonEncode(parsed.toMap());
      return true;
    } catch (_) {
      return false;
    }
  });
  if (usableLlmEntryIndex >= 0) {
    final existingEntry = existingEntries[usableLlmEntryIndex];
    final rawConfigs = existingEntry['configs'];
    final parsedEntry = ProviderEntry.fromMap(existingEntry);
    final configs = rawConfigs is List
        ? rawConfigs.whereType<Map<String, dynamic>>().toList()
        : (jsonDecode(
            _prepareLegacyChatConfigsSync(
              jsonEncode([existingEntry]),
            )['payload']! as String,
          ) as List)
            .whereType<Map<String, dynamic>>()
            .toList();
    final representedConfigs = rawConfigs is List ? configs : [existingEntry];
    final metadataMatchedConfigs = <Map<String, dynamic>>{};
    var metadataChanged = false;
    for (final represented in representedConfigs) {
      if (represented is! Map) continue;
      final existingConfig = Map<String, dynamic>.from(represented);
      for (final legacyConfig in migratedConfigs) {
        if (!_sameLegacyProviderConfig(existingConfig, legacyConfig)) continue;
        final merged = _mergeLegacySafeMetadata(existingConfig, legacyConfig);
        if (merged == null) {
          return {'status': 'conflict', 'corruptExisting': corruptExisting};
        }
        metadataChanged = metadataChanged || merged;
        if (legacyConfig.containsKey('credentialRef') ||
            legacyConfig.containsKey('publicKey')) {
          metadataMatchedConfigs.add(legacyConfig);
        }
        if (merged && rawConfigs is List) {
          final target = represented as Map;
          target
            ..clear()
            ..addAll(existingConfig);
        }
      }
    }
    final representedIdentities = representedConfigs
        .map(
          (config) => _legacyChatConfigIdentity(
            config,
            legacyFormat: rawConfigs is! List,
          ),
        )
        .toSet();
    final unrepresentedConfigs = migratedConfigs
        .where(
          (config) =>
              !metadataMatchedConfigs.contains(config) &&
              representedIdentities.add(_legacyChatConfigIdentity(config)),
        )
        .toList();
    if (unrepresentedConfigs.isEmpty) {
      if (metadataChanged) {
        return {
          'status': 'write',
          'corruptExisting': corruptExisting,
          'payload': jsonEncode(existingEntries),
        };
      }
      return {'status': 'alreadyMigrated', 'corruptExisting': corruptExisting};
    }
    configs.addAll(unrepresentedConfigs);
    existingEntry['configs'] = configs;
    return {
      'status': 'write',
      'corruptExisting': corruptExisting,
      'payload': jsonEncode(existingEntries),
    };
  }

  existingEntries.add({
    'id': 'migrated_llm',
    'type': 'llm',
    'name': 'LLM供应商',
    'configs': migratedConfigs,
  });
  return {
    'status': 'write',
    'corruptExisting': corruptExisting,
    'payload': jsonEncode(existingEntries),
  };
}

String _legacyChatConfigIdentity(
  Map<String, dynamic> config, {
  bool legacyFormat = false,
}) =>
    jsonEncode([
      config['providerName'] is String ? config['providerName'] : '',
      config['host'] is String ? config['host'] : '',
      config['key'] is String ? config['key'] : '',
      (config['models'] is List ? config['models'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map((model) {
        final typeConfig = model['typeConfig'] is Map
            ? Map<String, dynamic>.from(model['typeConfig'] as Map)
            : <String, dynamic>{};
        final temperature = model['temperature'];
        if (temperature != null) typeConfig['temperature'] = temperature;
        final context = model['maxTokens'] ?? model['context'];
        if (context != null) typeConfig['context'] = context;
        return [
          model['modelId'] is String ? model['modelId'] : '',
          model['supportStream'] is bool
              ? model['supportStream']
              : legacyFormat,
          _canonicalLegacyChatIdentityValue(typeConfig),
        ];
      }).toList(),
    ]);

Object? _canonicalLegacyChatIdentityValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.whereType<String>().toList()..sort();
    return {
      for (final key in keys)
        key: _canonicalLegacyChatIdentityValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalLegacyChatIdentityValue).toList();
  }
  return value;
}

bool _sameLegacyProviderConfig(
  Map<String, dynamic> existing,
  Map<String, dynamic> legacy,
) {
  if ((existing['providerName'] is String ? existing['providerName'] : '') !=
          (legacy['providerName'] is String ? legacy['providerName'] : '') ||
      (existing['host'] is String ? existing['host'] : '') !=
          (legacy['host'] is String ? legacy['host'] : '')) {
    return false;
  }
  List<String>? modelIds(Object? value) {
    if (value is! List) return null;
    if (value.isEmpty) return null;
    final result = <String>[];
    for (final item in value) {
      if (item is! Map) return null;
      final modelId = item['modelId'];
      final name = item['name'];
      final id = modelId is String && modelId.trim().isNotEmpty
          ? modelId
          : (name is String && name.trim().isNotEmpty ? name : '');
      if (id.isEmpty) return null;
      result.add(id);
    }
    return result;
  }

  final existingModels = modelIds(existing['models']);
  final legacyModels = modelIds(legacy['models']);
  return existingModels != null &&
      legacyModels != null &&
      jsonEncode(existingModels) == jsonEncode(legacyModels);
}

bool? _mergeLegacySafeMetadata(
  Map<String, dynamic> existing,
  Map<String, dynamic> legacy,
) {
  final existingKey = existing['key'];
  final legacyKey = legacy['key'];
  if (existingKey != null && existingKey is! String ||
      legacyKey != null && legacyKey is! String) {
    return null;
  }
  if (existingKey is String &&
      existingKey.isNotEmpty &&
      legacyKey is String &&
      legacyKey.isNotEmpty &&
      existingKey != legacyKey) {
    return null;
  }
  final existingReference = existing['credentialRef'];
  if (existingReference is String &&
      existingReference.isNotEmpty &&
      (existingKey == null || existingKey == '') &&
      legacyKey is String &&
      legacyKey.isNotEmpty) {
    // A legacy source cannot safely rotate a reference already used by the
    // provider entry. Keep both preferences intact for recovery or explicit
    // account-level rotation after migration.
    return null;
  }
  var changed = false;
  if ((existingKey == null || existingKey == '') &&
      legacyKey is String &&
      legacyKey.isNotEmpty) {
    existing['key'] = legacyKey;
    changed = true;
  }
  for (final field in const ['credentialRef', 'publicKey']) {
    final current = existing[field];
    final incoming = legacy[field];
    if (current != null && (current is! String || current.trim().isEmpty) ||
        incoming != null && (incoming is! String || incoming.trim().isEmpty)) {
      return null;
    }
    if (current != null && incoming != null && current != incoming) {
      return null;
    }
    if (current == null && incoming != null) {
      existing[field] = incoming;
      changed = true;
    }
  }
  return changed;
}

Map<String, Object?> _fixProviderEntriesSync(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (error) {
    return {'status': 'parseError', 'error': error.toString()};
  }
  if (decoded is! List) return {'status': 'notList'};

  final list = decoded.whereType<Map<String, dynamic>>().toList();
  var changed = false;
  for (var index = 0; index < list.length; index++) {
    final entry = list[index];
    final id = entry['id'];
    if (id is! String || id.isEmpty) {
      final type = entry['type'];
      final typeName = type is String ? type : 'unknown';
      entry['id'] = 'migrated_${typeName}_$index';
      changed = true;
    }

    final rawConfigs = entry['configs'];
    if (rawConfigs is List) {
      for (final config in rawConfigs) {
        if (config is! Map<String, dynamic>) continue;
        final rawModels = config['models'];
        if (rawModels is! List) continue;
        for (final model in rawModels) {
          if (model is! Map<String, dynamic>) continue;
          final rawCustomParams = model['customParams'];
          if (rawCustomParams is! List) continue;
          for (final param in rawCustomParams) {
            if (param is! Map<String, dynamic>) continue;
            if (param['type'] == null) {
              param['type'] = 'string';
              changed = true;
            }
          }
        }
      }
    }

    final entryType = entry['type'];
    if (entryType is! String || entryType.isEmpty) {
      entry['type'] = 'tts';
      changed = true;
    }
  }

  return {
    'status': 'ok',
    'changed': changed,
    if (changed) 'payload': jsonEncode(list),
  };
}
