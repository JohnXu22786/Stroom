import 'dart:convert';

import '../models/llm_account.dart';
import 'llm_credential_store.dart';

/// The persistence operations needed by the migration. Kept small so every
/// failure boundary can be exercised without a platform preference backend.
abstract interface class LlmAccountPreferences {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

class LlmAccountMigrationException implements Exception {
  const LlmAccountMigrationException();

  @override
  String toString() => 'LLM account migration could not be completed.';
}

class LlmAccountMigrationReport {
  final bool completed;
  final int accountsMigrated;
  final int modelGroupsCreated;

  const LlmAccountMigrationReport({
    required this.completed,
    this.accountsMigrated = 0,
    this.modelGroupsCreated = 0,
  });
}

/// Copies legacy provider credentials first, validates new account/group
/// records, then replaces legacy key fields with references. Before the final
/// source write, the old provider JSON remains the recovery copy. If a later
/// write fails, retrying this service completes from either that source or the
/// already-validated reference records.
class LlmAccountMigrationService {
  static const accountsPreferenceKey = 'llm_accounts_v1';
  static const modelGroupsPreferenceKey = 'llm_model_groups_v1';
  static const migrationStateKey = 'llm_account_migration_v1';

  final LlmAccountPreferences preferences;
  final LlmCredentialStore credentialStore;

  const LlmAccountMigrationService({
    required this.preferences,
    required this.credentialStore,
  });

  Future<LlmAccountMigrationReport> migrate({
    String? sourceProviderEntriesJson,
  }) async {
    try {
      return await _migrate(sourceProviderEntriesJson);
    } on LlmAccountMigrationException {
      rethrow;
    } catch (_) {
      // Platform, parser and storage exceptions can include source data. Keep
      // diagnostics generic; the caller can keep serving the legacy settings.
      throw const LlmAccountMigrationException();
    }
  }

  Future<LlmAccountMigrationReport> _migrate(String? suppliedSource) async {
    final marker = await preferences.getString(migrationStateKey);
    final source = suppliedSource ??
        await preferences.getString('provider_entries') ??
        '[]';
    if (suppliedSource == null &&
        _isComplete(marker) &&
        !_containsLegacyCredential(source)) {
      return const LlmAccountMigrationReport(completed: true);
    }
    final decodedSource = jsonDecode(source);
    if (decodedSource is! List) throw const LlmAccountMigrationException();
    final entries = decodedSource
        .map((item) => item is Map ? Map<String, dynamic>.from(item) : item)
        .toList();

    final accountJson = await preferences.getString(accountsPreferenceKey);
    final groupJson = await preferences.getString(modelGroupsPreferenceKey);
    final accounts = _readRecords(accountJson);
    final groups = _readRecords(groupJson);
    final accountsById = <String, Map<String, dynamic>>{
      for (final record in accounts)
        if (record['id'] is String) record['id'] as String: record,
    };
    final groupsById = <String, Map<String, dynamic>>{
      for (final record in groups)
        if (record['id'] is String) record['id'] as String: record,
    };
    var accountsChanged = false;
    var groupsChanged = false;
    var accountsMigrated = 0;
    var groupsCreated = 0;
    final seenAccountIds = <String>{};
    final credentialValuesByReference = <String, String?>{};

    for (final entryValue in entries) {
      if (entryValue is! Map<String, dynamic> || entryValue['type'] != 'llm') {
        continue;
      }
      final rawEntryKey = entryValue['key'];
      if (rawEntryKey != null && rawEntryKey is! String) {
        throw const LlmAccountMigrationException();
      }
      final entryKey = rawEntryKey is String ? rawEntryKey : '';
      final rawConfigs = entryValue['configs'];
      if (rawConfigs == null) {
        if (entryKey.isNotEmpty) {
          // The startup model migration normally normalizes old single-config
          // entries first. Keep an unnormalized secret source recoverable if
          // this service is called before that migration succeeds.
          throw const LlmAccountMigrationException();
        }
        entryValue.remove('key');
        continue;
      }
      if (rawConfigs is! List) throw const LlmAccountMigrationException();
      if (entryKey.isNotEmpty) {
        if (rawConfigs.length != 1 || rawConfigs.single is! Map) {
          throw const LlmAccountMigrationException();
        }
        final onlyConfig = rawConfigs.single as Map;
        final configKey = onlyConfig['key'];
        if (configKey != null && configKey is! String) {
          throw const LlmAccountMigrationException();
        }
        if (configKey is String &&
            configKey.isNotEmpty &&
            configKey != entryKey) {
          // There is no safe way to choose between different secrets.
          throw const LlmAccountMigrationException();
        }
        if (configKey == null || configKey == '') {
          onlyConfig['key'] = entryKey;
        }
      }
      entryValue.remove('key');

      for (final configValue in rawConfigs) {
        if (configValue is! Map) throw const LlmAccountMigrationException();
        final config = Map<String, dynamic>.from(configValue);
        final accountId = config['id'];
        if (accountId is! String || accountId.isEmpty) {
          throw const LlmAccountMigrationException();
        }
        if (!seenAccountIds.add(accountId)) {
          throw const LlmAccountMigrationException();
        }
        final rawKey = config['key'];
        if (rawKey != null && rawKey is! String) {
          throw const LlmAccountMigrationException();
        }
        final key = rawKey is String ? rawKey : '';
        final existingRef = config['credentialRef'];
        if (existingRef != null && existingRef is! String) {
          throw const LlmAccountMigrationException();
        }
        final credentialRef = key.isNotEmpty
            ? (existingRef as String? ?? _credentialReference(accountId))
            : existingRef as String?;

        if (key.isNotEmpty) {
          final reference = credentialRef!;
          final referenceWasRecorded =
              credentialValuesByReference.containsKey(reference);
          final previousValue = credentialValuesByReference[reference];
          if (previousValue != null && previousValue != key) {
            // A shared secure reference cannot safely represent two legacy
            // credentials. Abort while the original provider entries remain.
            throw const LlmAccountMigrationException();
          }
          if (referenceWasRecorded && previousValue == null) {
            final existingCredential = await credentialStore.read(reference);
            if (existingCredential != null && existingCredential != key) {
              throw const LlmAccountMigrationException();
            }
          }
          credentialValuesByReference[reference] = key;
          await _storeAndVerify(reference, key);
          config['credentialRef'] = reference;
        } else if (credentialRef != null) {
          credentialValuesByReference.putIfAbsent(credentialRef, () => null);
        }

        final modelMappings = _mapModels(accountId, config);
        final oldAccount = accountsById[accountId] ?? const {};
        final oldAccountFields = Map<String, dynamic>.from(oldAccount)
          ..remove('credentialRef');
        final endpointConfig = Map<String, dynamic>.from(config)
          ..remove('id')
          ..remove('key')
          ..remove('credentialRef')
          ..remove('models');
        final account = <String, dynamic>{
          ...oldAccountFields,
          'id': accountId,
          'connectorType': config['connectorType'] is String
              ? config['connectorType']
              : (config['endpointType'] is String
                  ? config['endpointType']
                  : 'openai'),
          'authType': config['authType'] is String
              ? config['authType']
              : (credentialRef == null ? 'none' : 'api_key'),
          'displayName': config['providerName'] is String
              ? config['providerName']
              : (config['name'] is String ? config['name'] : accountId),
          'status': oldAccount['status'] ?? LlmAccountStatus.unknown.name,
          'endpointConfig': endpointConfig,
          'models': modelMappings,
          'policy': oldAccount['policy'] ?? LlmRoutingPolicy().toMap(),
          'usageByWindow': oldAccount['usageByWindow'] ?? _unknownUsage(),
        };
        if (credentialRef != null) {
          account['credentialRef'] = credentialRef;
        }
        if (!_jsonEqual(oldAccount, account)) {
          accountsById[accountId] = account;
          accountsChanged = true;
        }
        accountsMigrated++;

        for (var index = 0; index < modelMappings.length; index++) {
          final model = modelMappings[index];
          final localModelId = model['id'] as String;
          final upstreamModelId = model['upstreamModelId'] as String;
          final groupId = _modelGroupId(accountId, localModelId);
          final oldGroup = groupsById[groupId];
          final members = oldGroup == null
              ? <Map<String, dynamic>>[]
              : _readMembers(oldGroup['members']);
          final memberIndex = members.indexWhere(
            (member) =>
                member['accountId'] == accountId &&
                member['upstreamModelId'] == upstreamModelId,
          );
          if (memberIndex < 0) {
            members.add({
              'accountId': accountId,
              'upstreamModelId': upstreamModelId,
              'localModelId': localModelId,
              'priorityTier': 0,
            });
          }
          final group = <String, dynamic>{
            ...?oldGroup,
            'id': groupId,
            'displayName': oldGroup?['displayName'] ?? model['displayName'],
            'members': members,
            'policy': oldGroup?['policy'] ?? LlmRoutingPolicy().toMap(),
          };
          if (!_jsonEqual(oldGroup, group)) {
            groupsById[groupId] = group;
            groupsChanged = true;
            if (oldGroup == null) groupsCreated++;
          }
        }

        if (key.isNotEmpty) {
          config.remove('key');
        } else if (config.containsKey('key')) {
          // Empty legacy fields are not needed by any reader once the
          // migration has validated the rest of this config.
          config.remove('key');
        }
        if (credentialRef != null) {
          config['credentialRef'] = credentialRef;
        }
        final configIndex = rawConfigs.indexOf(configValue);
        rawConfigs[configIndex] = config;
      }
    }

    final orderedAccounts = accountsById.values.toList();
    final orderedGroups = groupsById.values.toList();
    final accountEnvelope = _envelope(orderedAccounts);
    final groupEnvelope = _envelope(orderedGroups);

    // New records and all credential references are durable and read-back
    // validated before the source provider entries can be scrubbed.
    if (accountsChanged || accountJson == null) {
      await _writeAndVerify(accountsPreferenceKey, accountEnvelope);
    } else {
      await _validateStoredEnvelope(accountsPreferenceKey, accountEnvelope);
    }
    if (groupsChanged || groupJson == null) {
      await _writeAndVerify(modelGroupsPreferenceKey, groupEnvelope);
    } else {
      await _validateStoredEnvelope(modelGroupsPreferenceKey, groupEnvelope);
    }
    await _validateMappedReferences(
      entries,
      accountsById,
      groupsById,
      requireCredentialPresence: !_isComplete(marker),
    );

    final sanitizedSource = jsonEncode(entries);
    if (sanitizedSource != source) {
      await _writeAndVerify('provider_entries', sanitizedSource);
    } else {
      final persistedSource = await preferences.getString('provider_entries');
      if (suppliedSource == null && persistedSource != sanitizedSource) {
        await _writeAndVerify('provider_entries', sanitizedSource);
      }
    }

    final completeMarker = jsonEncode({
      'version': 1,
      'status': 'complete',
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (!_isComplete(marker)) {
      await _writeAndVerify(migrationStateKey, completeMarker);
    }
    return LlmAccountMigrationReport(
      completed: true,
      accountsMigrated: accountsMigrated,
      modelGroupsCreated: groupsCreated,
    );
  }

  Future<void> _storeAndVerify(String reference, String secret) async {
    final current = await credentialStore.read(reference);
    if (current != secret) await credentialStore.write(reference, secret);
    final saved = await credentialStore.read(reference);
    if (saved != secret) throw const LlmAccountMigrationException();
  }

  Future<void> _validateMappedReferences(
      List<dynamic> entries,
      Map<String, Map<String, dynamic>> accounts,
      Map<String, Map<String, dynamic>> groups,
      {required bool requireCredentialPresence}) async {
    for (final entry in entries.whereType<Map<String, dynamic>>()) {
      if (entry['type'] != 'llm') continue;
      final configs = entry['configs'];
      if (configs is! List) continue;
      for (final config in configs.whereType<Map>()) {
        final key = config['key'];
        if (key is String && key.isNotEmpty) {
          throw const LlmAccountMigrationException();
        }
        final reference = config['credentialRef'];
        if (reference != null && reference is! String) {
          throw const LlmAccountMigrationException();
        }
        if (reference is String && requireCredentialPresence) {
          final credential = await credentialStore.read(reference);
          if (credential == null) {
            throw const LlmAccountMigrationException();
          }
        }
        final accountId = config['id'];
        if (accountId is! String || !accounts.containsKey(accountId)) {
          throw const LlmAccountMigrationException();
        }
        final account = accounts[accountId]!;
        if (account['credentialRef'] != reference) {
          throw const LlmAccountMigrationException();
        }
        final mappedModels = _mapModels(
          accountId,
          Map<String, dynamic>.from(config),
        );
        final accountModels = account['models'];
        if (accountModels is! List) {
          throw const LlmAccountMigrationException();
        }
        for (final model in mappedModels) {
          final localModelId = model['id'] as String;
          final upstreamModelId = model['upstreamModelId'];
          final hasAccountModel = accountModels.whereType<Map>().any(
                (item) =>
                    item['id'] == localModelId &&
                    item['upstreamModelId'] == upstreamModelId,
              );
          final group = groups[_modelGroupId(accountId, localModelId)];
          final members = group?['members'];
          final hasGroupMember = members is List &&
              members.whereType<Map>().any(
                    (item) =>
                        item['accountId'] == accountId &&
                        item['upstreamModelId'] == upstreamModelId,
                  );
          if (!hasAccountModel || !hasGroupMember) {
            throw const LlmAccountMigrationException();
          }
        }
      }
    }
  }

  Future<void> _writeAndVerify(String key, String value) async {
    final saved = await preferences.setString(key, value);
    if (!saved || await preferences.getString(key) != value) {
      throw const LlmAccountMigrationException();
    }
  }

  Future<void> _validateStoredEnvelope(String key, String expected) async {
    final saved = await preferences.getString(key);
    if (saved != expected) throw const LlmAccountMigrationException();
  }

  List<Map<String, dynamic>> _mapModels(
    String accountId,
    Map<String, dynamic> config,
  ) {
    final rawModels = config['models'];
    if (rawModels == null) return const [];
    if (rawModels is! List) throw const LlmAccountMigrationException();
    final models = <Map<String, dynamic>>[];
    for (var index = 0; index < rawModels.length; index++) {
      final rawValue = rawModels[index];
      if (rawValue is! Map) throw const LlmAccountMigrationException();
      final raw = Map<String, dynamic>.from(rawValue);
      final localId = raw['id'] is String && (raw['id'] as String).isNotEmpty
          ? raw['id'] as String
          : '$accountId:$index';
      final modelId = raw['modelId'] is String
          ? raw['modelId'] as String
          : (raw['name'] is String ? raw['name'] as String : '');
      final capabilities = <String, dynamic>{
        if (raw['supportStream'] is bool) 'streaming': raw['supportStream'],
        if (raw['supportInstruction'] is bool)
          'instruction': raw['supportInstruction'],
      };
      models.add({
        'id': localId,
        'upstreamModelId': modelId,
        'displayName': raw['name'] is String ? raw['name'] : modelId,
        'capabilities': capabilities,
        // Keep the full legacy model record so later request adapters can
        // continue to read any existing per-model fields.
        'config': raw,
      });
    }
    return models;
  }

  List<Map<String, dynamic>> _readRecords(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! Map || decoded['items'] is! List) {
      throw const LlmAccountMigrationException();
    }
    final records = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final item in decoded['items'] as List) {
      if (item is! Map) throw const LlmAccountMigrationException();
      final record = Map<String, dynamic>.from(item);
      final id = record['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) {
        throw const LlmAccountMigrationException();
      }
      records.add(record);
    }
    return records;
  }

  List<Map<String, dynamic>> _readMembers(Object? raw) {
    if (raw is! List) throw const LlmAccountMigrationException();
    final members = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) throw const LlmAccountMigrationException();
      members.add(Map<String, dynamic>.from(item));
    }
    return members;
  }

  String _envelope(List<Map<String, dynamic>> items) =>
      jsonEncode({'version': 1, 'items': items});

  Map<String, dynamic> _unknownUsage() => {
        for (final window in LlmUsageWindow.values)
          window.name: const LlmUsageWindowState().toMap(),
      };

  String _credentialReference(String accountId) =>
      'stroom.llm.credential.${Uri.encodeComponent(accountId)}';

  String _modelGroupId(String accountId, String localModelId) {
    final encodedAccountId = Uri.encodeComponent(accountId);
    final encodedLocalModelId = Uri.encodeComponent(localModelId);
    return 'stroom.model-group.${encodedAccountId.length}:$encodedAccountId'
        '${encodedLocalModelId.length}:$encodedLocalModelId';
  }

  bool _isComplete(String? marker) {
    if (marker == null || marker.isEmpty) return false;
    try {
      final decoded = jsonDecode(marker);
      return decoded is Map && decoded['status'] == 'complete';
    } catch (_) {
      return false;
    }
  }

  bool _containsLegacyCredential(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return true;
      for (final entry in decoded.whereType<Map>()) {
        if (entry['type'] != 'llm') continue;
        if (entry.containsKey('key')) return true;
        if (entry['configs'] is! List) continue;
        for (final config in (entry['configs'] as List).whereType<Map>()) {
          if (config['key'] is String && (config['key'] as String).isNotEmpty) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      // A complete marker must not suppress recovery of malformed or restored
      // legacy data. The normal parser will fail without changing its source.
      return true;
    }
  }

  bool _jsonEqual(Object? left, Object? right) =>
      jsonEncode(left) == jsonEncode(right);
}
