import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tts_models.dart';

export '../models/tts_models.dart';

export 'provider_config_types.dart';
part 'provider_config_persistence.dart';

// ============================================================================
// 供应商条目列表状态
// ============================================================================

class ProviderEntriesState {
  final List<ProviderEntry> entries;

  const ProviderEntriesState({this.entries = const []});
}

/// 供应商条目列表提供器（持久化）
final providerEntriesProvider =
    StateNotifierProvider<ProviderEntriesNotifier, ProviderEntriesState>((ref) {
  final notifier = ProviderEntriesNotifier();
  notifier.load();
  return notifier;
});

class ProviderEntriesNotifier extends StateNotifier<ProviderEntriesState> {
  ProviderEntriesNotifier() : super(const ProviderEntriesState());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 第1步：迁移旧版 chat_configs → provider_entries
      await _migrateOldChatConfigs(prefs);

      // 第2步：迁移旧版 CustomParam 缺少 type 字段的问题
      await _migrateOldCustomParams(prefs);

      // 第3步：正常加载 provider_entries
      final json = prefs.getString('provider_entries');
      if (json != null && json.isNotEmpty) {
        final List<dynamic> rawList;
        try {
          rawList = jsonDecode(json) as List;
        } catch (e) {
          // 结构性损坏（非法 JSON）：备份原始数据再回退默认预置，
          // 否则后续任意 CRUD 的 _persist 会用默认值覆盖写坏，
          // 含 API key 的原始配置不可恢复地丢失。
          debugPrint('Failed to decode provider_entries: $e');
          await _backupCorruptProviderEntries(prefs, json);
          state = _defaultEntries();
          return;
        }

        // 逐条容错解析：单条损坏（类型错误等）跳过、保留其余——
        // 对齐 conversations 的防御风格。整表回退会导致含 API key
        // 的配置静默丢失且被后续 _persist 覆盖。
        final entries = <ProviderEntry>[];
        for (final raw in rawList) {
          if (raw is! Map) continue;
          try {
            entries.add(ProviderEntry.fromMap(Map<String, dynamic>.from(raw)));
          } catch (e) {
            debugPrint('Skipping corrupt provider entry: $e');
          }
        }
        if (entries.isEmpty) {
          // 全部条目损坏：备份并回退默认（保留原始数据供恢复）
          await _backupCorruptProviderEntries(prefs, json);
          state = _defaultEntries();
          return;
        }

        // 第4步：确保 OCR 条目存在（已有用户升级时自动迁移）
        final hasOcr = entries.any((e) => e.type == 'ocr');
        if (!hasOcr) {
          entries.add(
            ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        // 第5步：确保 ASR（语音识别）条目存在（已有用户升级时自动迁移）
        final hasAsr = entries.any((e) => e.type == 'asr');
        if (!hasAsr) {
          entries.add(
            ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
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
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        } else {
          // 第7步：确保已有的 MCP 条目包含内置 MCP 配置
          await _migrateBuiltinMcpConfigs(prefs, entries);
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
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }
        final hasLlm = entries.any((e) => e.type == 'llm');
        if (!hasLlm) {
          entries.add(
            ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        state = ProviderEntriesState(entries: entries);
        return;
      }
    } catch (e) {
      debugPrint('Failed to load provider entries: $e');
    }

    // 默认预置
    state = _defaultEntries();
  }

  /// 默认预置条目（全新安装 / 全部损坏回退）。
  ProviderEntriesState _defaultEntries() {
    return ProviderEntriesState(
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
    state = ProviderEntriesState(entries: [entry, ...state.entries]);
    await _persist();
  }

  /// 更新条目
  Future<void> update(String id, ProviderEntry updated) async {
    state = ProviderEntriesState(
      entries: state.entries.map((e) => e.id == id ? updated : e).toList(),
    );
    await _persist();
  }

  /// 删除条目
  Future<void> remove(String id) async {
    state = ProviderEntriesState(
      entries: state.entries.where((e) => e.id != id).toList(),
    );
    await _persist();
  }
}
