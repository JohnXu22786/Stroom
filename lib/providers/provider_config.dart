import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai_gateway/ai_gateway.dart';
import '../models/mcp.dart';
import '../models/mcp_provider_group.dart';
import '../models/llm_account.dart';
import '../models/tts_models.dart';
import '../services/llm_account_migration_service.dart';
import '../services/llm_model_group_provider.dart';
import '../services/llm_credential_store.dart';
import '../services/provider_model_migration.dart';
import '../services/data_migration_service.dart';

export '../models/tts_models.dart';
export '../models/mcp_provider_group.dart';

export 'provider_config_types.dart';
part 'provider_config_persistence.dart';

/// Stable identity and label for the local Google/Bing/Baidu web search group.
/// The callable tool name remains `web_search` for API and saved-tool compatibility.
const kBuiltinWebSearchEntryId = 'builtin';
const kBuiltinWebSearchEntryType = 'builtin_tool';
const kBuiltinWebSearchEntryName = 'Built-in Web Search';

/// Static read-only catalog row for local web search; it is never persisted
/// with the configurable provider entries.
ProviderEntry createBuiltinWebSearchEntry() => ProviderEntry(
      id: kBuiltinWebSearchEntryId,
      type: kBuiltinWebSearchEntryType,
      name: kBuiltinWebSearchEntryName,
    );

// ============================================================================
// 供应商条目列表状态
// ============================================================================

class ProviderEntriesState {
  final List<ProviderEntry> entries;
  final List<McpProviderGroup> mcpGroups;

  /// False only while the notifier is reading and migrating persisted entries.
  final bool isLoaded;
  final bool llmCredentialMigrationUnavailable;
  final bool llmModelGroupCatalogUnavailable;

  const ProviderEntriesState({
    this.entries = const [],
    this.mcpGroups = builtinMcpProviderGroups,
    this.isLoaded = true,
    this.llmCredentialMigrationUnavailable = false,
    this.llmModelGroupCatalogUnavailable = false,
  });

  ProviderEntriesState copyWith({
    List<ProviderEntry>? entries,
    List<McpProviderGroup>? mcpGroups,
  }) =>
      ProviderEntriesState(
        entries: entries ?? this.entries,
        mcpGroups: mcpGroups ?? this.mcpGroups,
        isLoaded: isLoaded,
        llmCredentialMigrationUnavailable: llmCredentialMigrationUnavailable,
        llmModelGroupCatalogUnavailable: llmModelGroupCatalogUnavailable,
      );
}

/// Removes legacy selector rows when their account is explicitly deleted.
/// OCR rows keep a source config ID so stale Task Flow inputs cannot recreate
/// the deleted account and credential.
ProviderEntriesState removeLegacyLlmAccountSourceConfigs(
  ProviderEntriesState state,
  LlmAccount account,
) =>
    removeLegacyLlmAccountSourceConfigsById(
      state,
      accountId: account.id,
      endpointConfig: account.endpointConfig,
    );

/// Account-management UI adapter that only needs the safe account identifier
/// and legacy OCR source marker exposed through the Gateway contract.
ProviderEntriesState removeLegacyLlmAccountSourceConfigsById(
  ProviderEntriesState state, {
  required String accountId,
  required Map<String, dynamic> endpointConfig,
}) {
  final legacyOcrConfigId = endpointConfig['legacyOcrProviderConfigId'];
  var changed = false;
  final entries = state.entries.map((entry) {
    final configs = entry.configs.where((config) {
      final removeLlmSource = entry.type == 'llm' && config.id == accountId;
      final removeOcrSource = legacyOcrConfigId is String &&
          legacyOcrConfigId.isNotEmpty &&
          entry.type == 'ocr' &&
          config.id == legacyOcrConfigId;
      return !(removeLlmSource || removeOcrSource);
    }).toList(growable: false);
    if (configs.length == entry.configs.length) return entry;
    changed = true;
    return ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      enabled: entry.enabled,
      legacyFields: entry.legacyFields,
      configs: configs,
    );
  }).toList(growable: false);
  if (!changed) return state;
  return ProviderEntriesState(
    entries: entries,
    mcpGroups: state.mcpGroups,
    isLoaded: state.isLoaded,
    llmCredentialMigrationUnavailable: state.llmCredentialMigrationUnavailable,
    llmModelGroupCatalogUnavailable: state.llmModelGroupCatalogUnavailable,
  );
}

bool isMcpProviderConfigEnabled(
  ProviderConfigItem config,
  List<McpProviderGroup> groups,
) {
  final groupId = config.groupId ?? defaultMcpGroupIdForConfig(config);
  return groups.where((group) => group.id == groupId).firstOrNull?.enabled ??
      true;
}

String defaultMcpGroupIdForConfig(ProviderConfigItem config) {
  final stableHttpToolName = config.models.isNotEmpty &&
          config.models[0].typeConfig['isHttpTool'] == true
      ? config.models[0].name
      : null;
  return defaultMcpGroupIdForProvider(
    config.providerName,
    stableHttpToolName: stableHttpToolName,
  );
}

/// Assigns stable placeholder names across all MCP configs, including disabled
/// groups, so toggling groups or reordering configs never changes tool names.
Map<String, String> mcpPlaceholderToolNamesByConfigId(
  Iterable<ProviderConfigItem> configs,
) {
  final serverNamesByConfigId = <String, String>{};
  final configIdsByBaseName = <String, List<String>>{};
  for (final config in configs) {
    final typeConfig =
        config.models.isNotEmpty ? config.models[0].typeConfig : null;
    if (typeConfig?['isHttpTool'] == true) continue;
    final serverConfig = McpServerConfig.fromProviderConfig(
      providerName: config.providerName,
      typeConfig: typeConfig,
    );
    if (serverConfig == null) continue;
    final baseName = McpServerConfig.placeholderToolName(serverConfig.name);
    serverNamesByConfigId[config.id] = serverConfig.name;
    configIdsByBaseName.putIfAbsent(baseName, () => []).add(config.id);
  }

  final namesByConfigId = <String, String>{};
  final usedNames = configIdsByBaseName.keys.toSet();
  final groupsByBaseName = configIdsByBaseName.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  for (final entry in groupsByBaseName) {
    final aliasesByServerName = <String, String>{};
    final configIds = List<String>.of(entry.value)..sort();
    for (final configId in configIds) {
      final serverName = serverNamesByConfigId[configId]!;
      aliasesByServerName.putIfAbsent(serverName, () {
        if (aliasesByServerName.isEmpty && entry.key.length <= 64) {
          return entry.key;
        }
        // Long base names need the same stable config-ID suffix as later
        // collisions so every published tool name stays within 64 chars.
        return _uniqueMcpPlaceholderToolName(entry.key, configId, usedNames);
      });
    }
    for (final configId in configIds) {
      namesByConfigId[configId] =
          aliasesByServerName[serverNamesByConfigId[configId]!]!;
    }
  }
  return namesByConfigId;
}

String _uniqueMcpPlaceholderToolName(
  String baseName,
  String configId,
  Set<String> usedNames,
) {
  final idPart = configId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final stableId = idPart.isEmpty ? 'config' : idPart;
  final baseStem = baseName.endsWith('_mcp')
      ? baseName.substring(0, baseName.length - 4)
      : baseName;
  final maxSuffixLength = stableId.length < 59 ? stableId.length : 59;
  var suffixLength = maxSuffixLength < 8 ? maxSuffixLength : 8;

  while (true) {
    final suffix = stableId.substring(stableId.length - suffixLength);
    final maxStemLength = 64 - suffix.length - 5;
    final stem = maxStemLength <= 0
        ? ''
        : baseStem.length <= maxStemLength
            ? baseStem
            : _truncateMcpToolNameStem(baseStem, maxStemLength);
    final name = '${stem}_${suffix}_mcp';
    if (usedNames.add(name)) return name;
    if (suffixLength < maxSuffixLength) {
      suffixLength += 4;
      if (suffixLength > maxSuffixLength) suffixLength = maxSuffixLength;
      continue;
    }
    for (var index = 2;; index++) {
      final indexText = index.toString();
      final suffixBudget = 58 - indexText.length;
      final duplicateSuffixLength =
          stableId.length <= suffixBudget ? stableId.length : suffixBudget;
      final duplicateSuffix = stableId.substring(
        stableId.length - duplicateSuffixLength,
      );
      final duplicateStemLength =
          64 - duplicateSuffix.length - indexText.length - 6;
      final duplicateStem = duplicateStemLength <= 0
          ? ''
          : baseStem.length <= duplicateStemLength
              ? baseStem
              : _truncateMcpToolNameStem(baseStem, duplicateStemLength);
      final duplicateName =
          '${duplicateStem}_${duplicateSuffix}_${indexText}_mcp';
      if (usedNames.add(duplicateName)) return duplicateName;
    }
  }
}

String _truncateMcpToolNameStem(String value, int maxCodeUnits) {
  final result = StringBuffer();
  var codeUnits = 0;
  for (final rune in value.runes) {
    final runeCodeUnits = rune > 0xFFFF ? 2 : 1;
    if (codeUnits + runeCodeUnits > maxCodeUnits) break;
    result.writeCharCode(rune);
    codeUnits += runeCodeUnits;
  }
  return result.toString();
}

String? mcpProviderConfigToolName(
  ProviderConfigItem config, {
  Map<String, String>? placeholderNamesByConfigId,
}) {
  final typeConfig =
      config.models.isNotEmpty ? config.models[0].typeConfig : null;
  if (typeConfig?['isHttpTool'] == true) {
    // The provider name is editable in the settings panel. Keep matching the
    // registered HTTP handler through the model's stable built-in name.
    return switch (config.models[0].name) {
      'Brave Search' => 'brave_web_search',
      'Bocha' => 'bocha_web_search',
      'Querit' => 'querit_search',
      'Searxng' => 'searxng_search',
      _ => null,
    };
  }
  final serverConfig = McpServerConfig.fromProviderConfig(
    providerName: config.providerName,
    typeConfig: typeConfig,
  );
  if (serverConfig == null) return null;
  final stableNames =
      placeholderNamesByConfigId ?? mcpPlaceholderToolNamesByConfigId([config]);
  return stableNames[config.id];
}

Set<String> disabledMcpToolNames(ProviderEntriesState state) {
  final mcpEntry =
      state.entries.where((entry) => entry.type == 'mcp').firstOrNull;
  final mcpConfigs = mcpEntry?.configs ?? const <ProviderConfigItem>[];
  final placeholderNamesByConfigId = mcpPlaceholderToolNamesByConfigId(
    mcpConfigs,
  );
  final disabled = <String>{};
  final active = <String>{};
  for (final config in mcpConfigs) {
    final name = mcpProviderConfigToolName(
      config,
      placeholderNamesByConfigId: placeholderNamesByConfigId,
    );
    if (name == null) continue;
    (isMcpProviderConfigEnabled(config, state.mcpGroups) ? active : disabled)
        .add(name);
  }
  disabled.removeAll(active);
  if (state.mcpGroups
          .where((group) => group.id == builtinSearchMcpGroupId)
          .firstOrNull
          ?.enabled ==
      false) {
    disabled.add('web_search');
  }
  return disabled;
}

/// 供应商条目列表提供器（持久化）
final providerEntriesProvider =
    StateNotifierProvider<ProviderEntriesNotifier, ProviderEntriesState>((ref) {
  final notifier = ProviderEntriesNotifier();
  notifier._loading = notifier.load();
  return notifier;
});

class ProviderEntriesNotifier extends StateNotifier<ProviderEntriesState> {
  final LlmCredentialStore _credentialStore;
  final Future<AiGatewayFacade> Function() _gatewayFactory;
  bool _providerEntriesSourceUnreadable = false;
  bool _reloadBeforeNextMutation = false;
  bool _lastLoadSucceeded = false;
  int _providerEntriesSourceConflictGeneration = 0;
  final Map<String, String> _conflictedEntryUpdateFingerprints = {};
  String? _loadedProviderEntriesSourceJson;

  ProviderEntriesNotifier({
    LlmCredentialStore? credentialStore,
    Future<AiGatewayFacade> Function()? gatewayFactory,
  })  : _credentialStore = credentialStore ?? PlatformLlmCredentialStore(),
        _gatewayFactory = gatewayFactory ?? AiGateway.createPlatform,
        super(const ProviderEntriesState(isLoaded: false));

  Future<void> _loading = Future<void>.value();
  Future<void> get ready => _loading;

  Future<void> load() async {
    _lastLoadSucceeded = false;
    _providerEntriesSourceUnreadable = false;
    _loadedProviderEntriesSourceJson = null;
    var mcpGroups = builtinMcpProviderGroups;
    var llmModelGroupCatalogUnavailable = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      mcpGroups = _readMcpGroups(prefs.getString('mcp_provider_groups'));

      // 第1步：迁移旧版 chat_configs → provider_entries
      await _migrateOldChatConfigs(prefs);

      // 第2步：迁移旧版 CustomParam 缺少 type 字段的问题
      await _migrateOldCustomParams(prefs);

      // 第2.5步：迁移旧版推理参数缺少 isEffortParam 标志的问题
      await _migrateLegacyEffortParams(prefs);

      // 第3步：正常加载 provider_entries
      final json = prefs.getString('provider_entries');
      if (json != null && json.isNotEmpty) {
        final List<dynamic> rawList;
        var credentialMigrationUnavailable = false;
        var sourceForLoad = json;
        String? providerEntriesJsonForLoad = json;
        try {
          jsonDecode(json) as List;
          // Stage stable IDs so a later secure-storage failure cannot leave
          // provider_entries partly migrated before credentials are safe.
          final modelMigratedJson =
              await ProviderModelMigration.migrateSettingsContent(json);
          sourceForLoad = modelMigratedJson;
          try {
            await LlmAccountMigrationService(
              preferences: _SharedPreferencesLlmAccountPreferences(prefs),
              credentialStore: _credentialStore,
            ).migrate(
              sourceProviderEntriesJson: modelMigratedJson,
              expectedStoredProviderEntriesJson: json,
            );
          } on LlmAccountMigrationException {
            _reloadBeforeNextMutation = true;
            debugPrint(
              'Secure credential migration is unavailable; legacy LLM settings are preserved.',
            );
            final currentSource = prefs.getString('provider_entries');
            if (currentSource == null || currentSource.isEmpty) {
              if (!mounted) return;
              state = ProviderEntriesState(
                isLoaded: false,
                mcpGroups: mcpGroups,
              );
              return;
            }
            if (currentSource != json) {
              try {
                sourceForLoad =
                    await ProviderModelMigration.migrateSettingsContent(
                  currentSource,
                );
              } catch (_) {
                if (!mounted) return;
                state = ProviderEntriesState(
                  isLoaded: false,
                  mcpGroups: mcpGroups,
                );
                return;
              }
            }
            providerEntriesJsonForLoad = currentSource;
            if (!_canServeLegacyProviderEntries(sourceForLoad, prefs)) {
              if (!mounted) return;
              state = ProviderEntriesState(
                isLoaded: false,
                mcpGroups: mcpGroups,
              );
              return;
            }
            // The legacy source is still authoritative and has no secure
            // references to hydrate. Keep it readable for settings and
            // existing model selectors, but do not let a later edit persist
            // it until secure migration can be retried successfully.
            credentialMigrationUnavailable = true;
          }
          if (credentialMigrationUnavailable) {
            rawList = jsonDecode(sourceForLoad) as List;
          } else {
            providerEntriesJsonForLoad = prefs.getString('provider_entries');
            if (providerEntriesJsonForLoad == null) {
              throw StateError('Provider settings disappeared during load.');
            }
            rawList = jsonDecode(providerEntriesJsonForLoad) as List;
          }
        } catch (_) {
          _providerEntriesSourceUnreadable = true;
          // 结构性损坏（非法 JSON）：备份原始数据再回退默认预置，
          // 否则后续任意 CRUD 的 _persist 会用默认值覆盖写坏，
          // 含 API key 的原始配置不可恢复地丢失。
          debugPrint('Failed to decode provider entries.');
          await _backupCorruptProviderEntries(prefs, json);
          if (!mounted) return;
          state = _defaultEntries(mcpGroups: mcpGroups);
          return;
        }

        // 逐条容错解析：单条损坏（类型错误等）跳过、保留其余——
        // 对齐 conversations 的防御风格。整表回退会导致含 API key
        // 的配置静默丢失且被后续 _persist 覆盖。
        final entries = <ProviderEntry>[];
        for (final raw in rawList) {
          if (raw is! Map) {
            _providerEntriesSourceUnreadable = true;
            continue;
          }
          try {
            entries.add(ProviderEntry.fromMap(Map<String, dynamic>.from(raw)));
          } catch (_) {
            _providerEntriesSourceUnreadable = true;
            debugPrint('Skipping a corrupt provider entry.');
          }
        }
        if (entries.isEmpty) {
          _providerEntriesSourceUnreadable = true;
          // 全部条目损坏：备份并回退默认（保留原始数据供恢复）
          await _backupCorruptProviderEntries(prefs, json);
          if (!mounted) return;
          state = _defaultEntries(mcpGroups: mcpGroups);
          return;
        }

        await _hydrateLlmCredentials(entries);

        // 第4步：确保 OCR 条目存在（已有用户升级时自动迁移）
        var entriesChanged = false;
        final hasOcr = entries.any((e) => e.type == 'ocr');
        if (!hasOcr) {
          entries.add(
            ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
          );
          entriesChanged = true;
        }

        // 第5步：确保 ASR（语音识别）条目存在（已有用户升级时自动迁移）
        final hasAsr = entries.any((e) => e.type == 'asr');
        if (!hasAsr) {
          entries.add(
            ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
          );
          entriesChanged = true;
        }

        // 第6步：确保 MCP 条目存在（已有用户升级时自动迁移）
        final hasMcp = entries.any((e) => e.type == 'mcp');
        if (!hasMcp) {
          entries.add(
            ProviderEntry(
              id: 'builtin_mcp',
              type: 'mcp',
              name: 'MCP供应商',
              configs: _createBuiltinMcpConfigs(),
            ),
          );
          entriesChanged = true;
        } else {
          // 第7步：确保已有的 MCP 条目包含内置 MCP 配置
          entriesChanged =
              await _migrateBuiltinMcpConfigs(entries) || entriesChanged;
        }

        // 第8步：确保 TTS 与 LLM 条目存在。v0 旧用户（有旧
        // chat_configs）迁移后条目集为 [migrated_llm, builtin_ocr,
        // builtin_asr, builtin_mcp]，缺少 TTS 供应商——TTS 配置 UI
        // 按 name == 'TTS供应商' 查找会直接不可用（需手动重建），
        // 与全新安装行为不一致。
        final hasTts = entries.any((e) => e.type == 'tts');
        if (!hasTts) {
          entries.add(
            ProviderEntry(id: 'builtin_tts', type: 'tts', name: 'TTS供应商'),
          );
          entriesChanged = true;
        }
        final hasLlm = entries.any((e) => e.type == 'llm');
        if (!hasLlm) {
          entries.add(
            ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
          );
          entriesChanged = true;
        }

        var groupAssignmentsChanged = false;
        final validGroupIds = mcpGroups.map((group) => group.id).toSet();
        for (final entry in entries.where((entry) => entry.type == 'mcp')) {
          for (final config in entry.configs) {
            if (config.groupId == null ||
                !validGroupIds.contains(config.groupId)) {
              config.groupId = defaultMcpGroupIdForConfig(config);
              groupAssignmentsChanged = true;
            }
          }
        }

        try {
          await _appendLlmModelGroupConfigs(entries);
        } catch (_) {
          // The account/group catalog is an optional selector overlay. Keep
          // existing provider settings readable when that separate catalog is
          // damaged; the failed migration still gates mutations on a reload.
          debugPrint('Failed to load LLM model groups for model selectors.');
          llmModelGroupCatalogUnavailable = true;
        }
        _loadedProviderEntriesSourceJson = providerEntriesJsonForLoad;
        if (!mounted) return;
        state = ProviderEntriesState(
          entries: entries,
          mcpGroups: mcpGroups,
          llmCredentialMigrationUnavailable: credentialMigrationUnavailable,
          llmModelGroupCatalogUnavailable: llmModelGroupCatalogUnavailable,
        );
        _reloadBeforeNextMutation = credentialMigrationUnavailable;
        if (entriesChanged ||
            groupAssignmentsChanged ||
            prefs.getString('mcp_provider_groups') !=
                jsonEncode(mcpGroups.map((group) => group.toMap()).toList())) {
          if (!credentialMigrationUnavailable) await _persist();
        }
        _lastLoadSucceeded = !_reloadBeforeNextMutation;
        return;
      }
      _loadedProviderEntriesSourceJson = json;
    } catch (_) {
      _providerEntriesSourceUnreadable = true;
      _reloadBeforeNextMutation = true;
      if (!mounted) return;
      state = ProviderEntriesState(isLoaded: false, mcpGroups: mcpGroups);
      return;
    }

    // 默认预置
    final defaultState = _defaultEntries(mcpGroups: mcpGroups);
    try {
      await _appendLlmModelGroupConfigs(defaultState.entries);
    } catch (_) {
      debugPrint('Failed to load LLM model groups for model selectors.');
      llmModelGroupCatalogUnavailable = true;
    }
    if (!mounted) return;
    state = ProviderEntriesState(
      entries: defaultState.entries,
      mcpGroups: defaultState.mcpGroups,
      isLoaded: defaultState.isLoaded,
      llmModelGroupCatalogUnavailable: llmModelGroupCatalogUnavailable,
    );
    if (!_providerEntriesSourceUnreadable) {
      _reloadBeforeNextMutation = false;
    }
    _lastLoadSucceeded =
        !_providerEntriesSourceUnreadable && !_reloadBeforeNextMutation;
  }

  Future<void> _reloadBeforeMutationIfNeeded() async {
    if (_reloadBeforeNextMutation) {
      await load();
      if (!_lastLoadSucceeded) {
        throw StateError('Provider settings must be reloaded before editing.');
      }
      _reloadBeforeNextMutation = false;
    }
    if (!state.isLoaded) {
      throw StateError('Provider settings are unavailable.');
    }
  }

  Future<void> _appendLlmModelGroupConfigs(
    List<ProviderEntry> entries,
  ) async {
    final gateway = await _gatewayFactory();
    final accountManagement = gateway.accountManagement;
    final accounts = await accountManagement.listAccounts();
    final groups = await accountManagement.listModelGroups();

    var llmEntryIndex = entries.indexWhere((entry) => entry.type == 'llm');
    if (llmEntryIndex < 0 && groups.isEmpty) return;
    if (llmEntryIndex < 0) {
      entries.add(
        ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
      );
    }
    llmEntryIndex = entries.indexWhere((entry) => entry.type == 'llm');
    final entry = entries[llmEntryIndex];
    final realConfigs = markUnsupportedGatewayLlmConfigs(
      entry.configs.where((config) => !isLlmModelGroupProviderConfig(config)),
      accounts,
      providerCatalog: gateway.providerCatalog,
    );
    final groupConfigs = buildGatewayModelGroupProviderConfigs(
      accounts: accounts,
      groups: groups,
      providerCatalog: gateway.providerCatalog,
    );
    entries[llmEntryIndex] = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      enabled: entry.enabled,
      legacyFields: entry.legacyFields,
      configs: [...realConfigs, ...groupConfigs],
    );
  }

  Future<void> _setStateAndPersist(ProviderEntriesState next) async {
    final previous = state;
    state = next;
    try {
      await _persist(rethrowOnFailure: true);
    } catch (_) {
      if (identical(state, next)) state = previous;
      rethrow;
    }
  }

  Future<void> _hydrateLlmCredentials(List<ProviderEntry> entries) async {
    for (final entry in entries.where((entry) => entry.type == 'llm')) {
      for (final config in entry.configs) {
        final reference = config.credentialRef;
        if (reference == null) continue;
        try {
          config.key = await _credentialStore.read(reference) ?? '';
        } on LlmCredentialStoreException {
          debugPrint('Secure credential storage is unavailable.');
          rethrow;
        }
      }
    }
  }

  bool _canServeLegacyProviderEntries(
    String json,
    SharedPreferences preferences,
  ) {
    if (preferences.getString(
              LlmAccountMigrationService.accountsPreferenceKey,
            ) !=
            null ||
        preferences.getString(LlmAccountMigrationService.migrationStateKey) !=
            null) {
      return false;
    }

    try {
      final rawEntries = jsonDecode(json);
      if (rawEntries is! List) return false;
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map || rawEntry['type'] != 'llm') continue;
        if (rawEntry['credentialRef'] != null) return false;
        final rawConfigs = rawEntry['configs'];
        if (rawConfigs is! List) return false;
        for (final rawConfig in rawConfigs) {
          if (rawConfig is! Map || rawConfig['credentialRef'] != null) {
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<McpProviderGroup> _readMcpGroups(String? json) {
    final saved = <String, McpProviderGroup>{};
    if (json != null && json.isNotEmpty) {
      try {
        final rawGroups = jsonDecode(json);
        if (rawGroups is List) {
          for (final raw in rawGroups.whereType<Map>()) {
            try {
              final group = McpProviderGroup.fromMap(
                Map<String, dynamic>.from(raw),
              );
              if (group.id.isNotEmpty && group.name.trim().isNotEmpty) {
                saved[group.id] = group;
              }
            } catch (_) {
              // Skip a malformed group without losing the remaining groups.
            }
          }
        }
      } catch (_) {
        debugPrint('Failed to decode MCP provider groups.');
      }
    }

    final groups = <McpProviderGroup>[
      for (final builtin in builtinMcpProviderGroups)
        builtin.copyWith(enabled: saved[builtin.id]?.enabled ?? true),
    ];
    final builtinIds =
        builtinMcpProviderGroups.map((group) => group.id).toSet();
    groups.addAll(
      saved.values.where((group) => !builtinIds.contains(group.id)).map(
            (group) => McpProviderGroup(
              id: group.id,
              name: group.name.trim(),
              enabled: group.enabled,
            ),
          ),
    );
    return groups;
  }

  /// 默认预置条目（全新安装 / 全部损坏回退）。
  ProviderEntriesState _defaultEntries({
    List<McpProviderGroup> mcpGroups = builtinMcpProviderGroups,
  }) {
    return ProviderEntriesState(
      mcpGroups: mcpGroups,
      entries: [
        ProviderEntry(id: 'builtin_tts', type: 'tts', name: 'TTS供应商'),
        ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
        ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
        ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
        ProviderEntry(
          id: 'builtin_mcp',
          type: 'mcp',
          name: 'MCP供应商',
          configs: _createBuiltinMcpConfigs(),
        ),
      ],
    );
  }

  /// 在列表第一个位置添加新条目
  Future<void> addFirst(ProviderEntry entry) async {
    await _reloadBeforeMutationIfNeeded();
    await _setStateAndPersist(
      state.copyWith(entries: [entry, ...state.entries]),
    );
  }

  /// 更新条目
  Future<void> update(
    String id,
    ProviderEntry updated, {
    bool requirePersistence = false,
  }) async {
    await _reloadBeforeMutationIfNeeded();
    final updateFingerprint = _entryUpdateFingerprint(updated);
    final conflictedFingerprint = _conflictedEntryUpdateFingerprints[id];
    if (conflictedFingerprint != null &&
        conflictedFingerprint == updateFingerprint) {
      // A whole-entry object that already failed against a concurrent update
      // must not be retried after the notifier reloads newer settings.
      throw StateError(
        'Provider settings changed before this update; reload and try again.',
      );
    }
    _conflictedEntryUpdateFingerprints.remove(id);
    final index = state.entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      if (requirePersistence) {
        throw StateError(
          'Provider entry was removed before it could be saved.',
        );
      }
      return;
    }
    final entries = List<ProviderEntry>.from(state.entries);
    entries[index] = updated;
    final conflictGeneration = _providerEntriesSourceConflictGeneration;
    try {
      await _setStateAndPersist(
        state.copyWith(entries: entries),
      );
    } catch (_) {
      if (_providerEntriesSourceConflictGeneration != conflictGeneration) {
        _conflictedEntryUpdateFingerprints[id] = updateFingerprint;
      }
      rethrow;
    }
  }

  String _entryUpdateFingerprint(ProviderEntry entry) => sha256
      .convert(utf8.encode(jsonEncode(entry.toCredentialMigrationMap())))
      .toString();

  /// 删除条目
  Future<void> remove(String id) async {
    await _reloadBeforeMutationIfNeeded();
    await _setStateAndPersist(
      state.copyWith(entries: state.entries.where((e) => e.id != id).toList()),
    );
  }

  Future<void> addMcpGroup(McpProviderGroup group) async {
    await _reloadBeforeMutationIfNeeded();
    await _setStateAndPersist(
      state.copyWith(mcpGroups: [...state.mcpGroups, group]),
    );
  }

  Future<void> updateMcpGroup(McpProviderGroup updated) async {
    await _reloadBeforeMutationIfNeeded();
    final current =
        state.mcpGroups.where((group) => group.id == updated.id).firstOrNull;
    if (current == null || current.isBuiltin) return;
    await _setStateAndPersist(
      state.copyWith(
        mcpGroups: state.mcpGroups
            .map((group) => group.id == updated.id ? updated : group)
            .toList(),
      ),
    );
  }

  Future<void> setMcpGroupEnabled(String id, bool enabled) async {
    await _reloadBeforeMutationIfNeeded();
    await _setStateAndPersist(
      state.copyWith(
        mcpGroups: state.mcpGroups
            .map(
              (group) =>
                  group.id == id ? group.copyWith(enabled: enabled) : group,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeMcpGroup(String id) async {
    await _reloadBeforeMutationIfNeeded();
    final group = state.mcpGroups.where((item) => item.id == id).firstOrNull;
    if (group == null || group.isBuiltin) return;
    final fallbackId = id == builtinMcpServicesGroupId
        ? builtinSearchMcpGroupId
        : builtinMcpServicesGroupId;
    final entries = state.entries.map((entry) {
      if (entry.type != 'mcp' ||
          !entry.configs.any((config) => config.groupId == id)) {
        return entry;
      }
      return ProviderEntry(
        id: entry.id,
        type: entry.type,
        name: entry.name,
        enabled: entry.enabled,
        configs: entry.configs.map((config) {
          final copy = config.copy();
          if (copy.groupId == id) copy.groupId = fallbackId;
          return copy;
        }).toList(),
      );
    }).toList();
    await _setStateAndPersist(
      state.copyWith(
        entries: entries,
        mcpGroups: state.mcpGroups.where((item) => item.id != id).toList(),
      ),
    );
  }

  Future<void> moveMcpConfigToGroup(String configId, String groupId) async {
    await _reloadBeforeMutationIfNeeded();
    final entries = state.entries.map((entry) {
      if (entry.type != 'mcp' ||
          !entry.configs.any((config) => config.id == configId)) {
        return entry;
      }
      return ProviderEntry(
        id: entry.id,
        type: entry.type,
        name: entry.name,
        enabled: entry.enabled,
        configs: entry.configs.map((config) {
          final copy = config.copy();
          if (copy.id == configId) copy.groupId = groupId;
          return copy;
        }).toList(),
      );
    }).toList();
    await _setStateAndPersist(
      state.copyWith(entries: entries),
    );
  }
}
