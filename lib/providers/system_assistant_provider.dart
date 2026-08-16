import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/built_in_assistants.dart';

// ============================================================================
// 系统助手设置 — 对话页自动任务的独立配置（模型 + 提示词）
// ============================================================================
//
// 两个可配置任务：
// - 标题生成（title assistant）
// - 上下文压缩（compaction assistant）
//
// 每个任务独立配置：
// - 使用的模型：null = 跟随对话页当前选中的模型；
//   非 null = 绝对身份（模型 ID + 供应商名，显示名兜底）。
// - 使用的提示词：null = 使用内置默认提示词（builtin:title / builtin:compaction）；
//   非 null = 用户自定义。
// ============================================================================

const String _kTitleModelIdKey = 'system_title_model_id';
const String _kTitleModelProviderKey = 'system_title_model_provider';
const String _kTitleModelNameKey = 'system_title_model_name';
const String _kTitlePromptKey = 'system_title_prompt';

const String _kCompactionModelIdKey = 'system_compaction_model_id';
const String _kCompactionModelProviderKey = 'system_compaction_model_provider';
const String _kCompactionModelNameKey = 'system_compaction_model_name';
const String _kCompactionPromptKey = 'system_compaction_prompt';

// 旧格式 key（v1：选择助手 ID）。加载时迁移到新格式后删除。
const String _kLegacyTitleAssistantIdKey = 'system_title_assistant_id';
const String _kLegacyCompactionAssistantIdKey =
    'system_compaction_assistant_id';

/// 单个任务的配置：模型引用 + 自定义提示词。
///
/// - 模型字段全空表示"跟随对话页当前模型"；
/// - [prompt] 为 null 或空表示"使用内置默认提示词"。
class SystemAssistantTaskConfig {
  /// 模型的 API 模型 ID（绝对身份，重命名显示名后仍可解析）。
  final String? modelId;

  /// 供应商名（绝对身份的一部分，用于消歧）。
  final String? providerName;

  /// 模型显示名（"模型名 | 供应商名"格式，对话页同款）兜底。
  final String? modelDisplayName;

  /// 自定义提示词；null/空 = 使用内置默认提示词。
  final String? prompt;

  const SystemAssistantTaskConfig({
    this.modelId,
    this.providerName,
    this.modelDisplayName,
    this.prompt,
  });

  bool get hasModel =>
      (modelId != null && modelId!.isNotEmpty) ||
      (modelDisplayName != null && modelDisplayName!.isNotEmpty);

  bool get hasPrompt => prompt != null && prompt!.isNotEmpty;

  /// 替换模型引用；[clearModel] = true 时清空（回到跟随对话页模型）。
  SystemAssistantTaskConfig copyWithModel({
    String? modelId,
    String? providerName,
    String? modelDisplayName,
    bool clearModel = false,
  }) =>
      SystemAssistantTaskConfig(
        modelId: clearModel ? null : (modelId ?? this.modelId),
        providerName: clearModel ? null : (providerName ?? this.providerName),
        modelDisplayName:
            clearModel ? null : (modelDisplayName ?? this.modelDisplayName),
        prompt: prompt,
      );

  /// 替换提示词；传 null 表示回到内置默认。
  SystemAssistantTaskConfig copyWithPrompt(String? prompt) =>
      SystemAssistantTaskConfig(
        modelId: modelId,
        providerName: providerName,
        modelDisplayName: modelDisplayName,
        prompt: prompt,
      );
}

/// 系统助手设置状态。
class SystemAssistantSettings {
  /// 标题生成任务配置（模型 + 提示词）。
  final SystemAssistantTaskConfig title;

  /// 上下文压缩任务配置（模型 + 提示词）。
  final SystemAssistantTaskConfig compaction;

  const SystemAssistantSettings({
    this.title = const SystemAssistantTaskConfig(),
    this.compaction = const SystemAssistantTaskConfig(),
  });

  SystemAssistantSettings copyWith({
    SystemAssistantTaskConfig? title,
    SystemAssistantTaskConfig? compaction,
  }) =>
      SystemAssistantSettings(
        title: title ?? this.title,
        compaction: compaction ?? this.compaction,
      );

  // 无 toMap：持久化走独立 prefs key（..._model_id 等），
  // 序列化整个对象无调用方。
}

final systemAssistantSettingsProvider = StateNotifierProvider<
    SystemAssistantSettingsNotifier, SystemAssistantSettings>((ref) {
  final notifier = SystemAssistantSettingsNotifier();
  notifier._load();
  return notifier;
});

class SystemAssistantSettingsNotifier
    extends StateNotifier<SystemAssistantSettings> {
  SystemAssistantSettingsNotifier() : super(const SystemAssistantSettings());

  /// 用户已修改过设置：异步 [_load] 不得覆盖（对齐
  /// ContextManagementSettingsNotifier 的 _userModified 守卫——
  /// 否则启动瞬间快速修改会被旧 prefs 值覆盖）。
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userModified) return;

      // 旧格式迁移（系统助手 v1 → v2）：v1 里用户可能选择了自定义助手，
      // 把该助手的 prompt 提升为新格式的"自定义提示词"，保持用户意图；
      // 内置助手无需迁移（默认即为内置提示词）。幂等：迁移后删除旧 key。
      await _migrateLegacyAssistant(
        prefs,
        _kLegacyTitleAssistantIdKey,
        _kTitlePromptKey,
      );
      await _migrateLegacyAssistant(
        prefs,
        _kLegacyCompactionAssistantIdKey,
        _kCompactionPromptKey,
      );

      // TOCTOU 守卫：迁移是带 await 的多步写入，期间用户可能已保存新
      // 配置（_userModified 置位）——再读一次，避免用迁移结果覆盖。
      if (_userModified) return;

      state = SystemAssistantSettings(
        title: _readTask(prefs,
            modelIdKey: _kTitleModelIdKey,
            modelProviderKey: _kTitleModelProviderKey,
            modelNameKey: _kTitleModelNameKey,
            promptKey: _kTitlePromptKey),
        compaction: _readTask(prefs,
            modelIdKey: _kCompactionModelIdKey,
            modelProviderKey: _kCompactionModelProviderKey,
            modelNameKey: _kCompactionModelNameKey,
            promptKey: _kCompactionPromptKey),
      );
    } catch (e) {
      debugPrint('Failed to load system assistant settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _writeTask(prefs,
          modelIdKey: _kTitleModelIdKey,
          modelProviderKey: _kTitleModelProviderKey,
          modelNameKey: _kTitleModelNameKey,
          promptKey: _kTitlePromptKey,
          task: state.title);
      await _writeTask(prefs,
          modelIdKey: _kCompactionModelIdKey,
          modelProviderKey: _kCompactionModelProviderKey,
          modelNameKey: _kCompactionModelNameKey,
          promptKey: _kCompactionPromptKey,
          task: state.compaction);
    } catch (e) {
      debugPrint('Failed to persist system assistant settings: $e');
    }
  }

  /// 设置标题生成任务的完整配置（模型 + 提示词）。
  Future<void> setTitleTask(SystemAssistantTaskConfig task) {
    _userModified = true;
    state = state.copyWith(title: task);
    return _persist();
  }

  /// 设置上下文压缩任务的完整配置（模型 + 提示词）。
  Future<void> setCompactionTask(SystemAssistantTaskConfig task) {
    _userModified = true;
    state = state.copyWith(compaction: task);
    return _persist();
  }

  // ── 持久化读写 ─────────────────────────────────────────────────

  SystemAssistantTaskConfig _readTask(
    SharedPreferences prefs, {
    required String modelIdKey,
    required String modelProviderKey,
    required String modelNameKey,
    required String promptKey,
  }) {
    return SystemAssistantTaskConfig(
      modelId: prefs.getString(modelIdKey),
      providerName: prefs.getString(modelProviderKey),
      modelDisplayName: prefs.getString(modelNameKey),
      prompt: prefs.getString(promptKey),
    );
  }

  Future<void> _writeTask(
    SharedPreferences prefs, {
    required String modelIdKey,
    required String modelProviderKey,
    required String modelNameKey,
    required String promptKey,
    required SystemAssistantTaskConfig task,
  }) async {
    for (final (key, value) in [
      (modelIdKey, task.modelId),
      (modelProviderKey, task.providerName),
      (modelNameKey, task.modelDisplayName),
      (promptKey, task.prompt),
    ]) {
      if (value != null && value.isNotEmpty) {
        await prefs.setString(key, value);
      } else {
        await prefs.remove(key);
      }
    }
  }

  /// 旧格式（v1：助手 ID）迁移为自定义提示词。
  ///
  /// - 内置助手 ID → 无需迁移（默认本就使用内置提示词）；
  /// - 用户助手 ID → 把该助手当前保存的 prompt 写入 [promptKey]
  ///   （尚未设置新格式自定义提示词、且用户未在迁移期间保存新配置时）。
  ///
  /// 幂等：迁移成功后删除旧 key；唯一保留旧 key 的情况是 assistants
  /// 数据存在但解析失败（无法读出用户意图）——留待下次启动重试，
  /// 避免"解析失败仍删除旧 key"导致唯一一份 v1 绑定永久丢失。
  Future<void> _migrateLegacyAssistant(
    SharedPreferences prefs,
    String legacyKey,
    String promptKey,
  ) async {
    final legacyId = prefs.getString(legacyKey);
    if (legacyId == null) return;
    try {
      final isBuiltIn = builtInSystemAssistantById(legacyId) != null;
      if (isBuiltIn) {
        // 内置助手：默认即内置提示词，无需迁移，清除旧 key。
        await prefs.remove(legacyKey);
        return;
      }
      // 用户助手：只在没有新格式自定义提示词、且用户未在迁移期间
      // 保存新配置时写入（_userModified 在 await 间隙可能已置位）。
      if (prefs.getString(promptKey) != null || _userModified) {
        await prefs.remove(legacyKey);
        return;
      }
      final assistantsJson = prefs.getString('assistants');
      if (assistantsJson == null || assistantsJson.isEmpty) {
        // 无助手数据：旧 ID 对应的助手已不存在，无从迁移，清除旧 key。
        await prefs.remove(legacyKey);
        return;
      }
      final list = jsonDecode(assistantsJson) as List;
      for (final raw in list) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['id'] == legacyId) {
          final prompt = map['prompt'] as String?;
          if (prompt != null && prompt.trim().isNotEmpty) {
            // 到此处已无 await 间隙：上方 _userModified 检查在本
            // 事件循环轮次内保持有效，无需再次检查。
            await prefs.setString(promptKey, prompt.trim());
          }
          break;
        }
      }
      // 正常完成（无论是否写入 prompt）：旧 key 已被消费，删除（幂等）。
      await prefs.remove(legacyKey);
    } catch (e) {
      // JSON 解析失败：保留旧 key，下次启动重试。
      debugPrint('Failed to migrate legacy system assistant settings: $e');
    }
  }
}

// ============================================================================
// 解析：任务配置 → 实际使用的 system prompt
// ============================================================================

/// 解析任务的实际提示词：自定义优先，未自定义时返回内置默认提示词。
///
/// [defaultAssistantId] 是该任务的内置助手 ID（标题/压缩），作为
/// 默认提示词的来源。
String? resolveSystemAssistantPrompt(
  SystemAssistantTaskConfig task, {
  required String defaultAssistantId,
}) {
  if (task.prompt != null && task.prompt!.isNotEmpty) return task.prompt;
  return builtInSystemAssistantById(defaultAssistantId)?.prompt;
}
