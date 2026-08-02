import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant.dart';
import '../models/built_in_assistants.dart';

// ============================================================================
// 系统助手设置 — 对话页自动任务使用的助手
// ============================================================================
//
// 两个可配置任务：
// - 标题生成（title assistant）
// - 上下文压缩（compaction assistant）
//
// 默认使用内置助手（builtin:title / builtin:compaction）；
// 用户可替换为自己的任意助手（此时使用该助手的 system prompt）。
// ============================================================================

const String _kTitleAssistantIdKey = 'system_title_assistant_id';
const String _kCompactionAssistantIdKey = 'system_compaction_assistant_id';

/// 系统助手设置状态。
class SystemAssistantSettings {
  /// 标题生成助手 ID（内置 ID 或用户助手 ID）。
  final String titleAssistantId;

  /// 上下文压缩助手 ID（内置 ID 或用户助手 ID）。
  final String compactionAssistantId;

  const SystemAssistantSettings({
    this.titleAssistantId = kBuiltInTitleAssistantId,
    this.compactionAssistantId = kBuiltInCompactionAssistantId,
  });

  SystemAssistantSettings copyWith({
    String? titleAssistantId,
    String? compactionAssistantId,
  }) =>
      SystemAssistantSettings(
        titleAssistantId: titleAssistantId ?? this.titleAssistantId,
        compactionAssistantId:
            compactionAssistantId ?? this.compactionAssistantId,
      );

  Map<String, String> toMap() => {
        _kTitleAssistantIdKey: titleAssistantId,
        _kCompactionAssistantIdKey: compactionAssistantId,
      };
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
  /// 否则启动瞬间快速选择助手会被旧 prefs 值覆盖）。
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userModified) return;
      final titleId =
          prefs.getString(_kTitleAssistantIdKey) ?? kBuiltInTitleAssistantId;
      final compactionId = prefs.getString(_kCompactionAssistantIdKey) ??
          kBuiltInCompactionAssistantId;
      state = SystemAssistantSettings(
        titleAssistantId: titleId,
        compactionAssistantId: compactionId,
      );
    } catch (e) {
      debugPrint('Failed to load system assistant settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTitleAssistantIdKey, state.titleAssistantId);
      await prefs.setString(
          _kCompactionAssistantIdKey, state.compactionAssistantId);
    } catch (e) {
      debugPrint('Failed to persist system assistant settings: $e');
    }
  }

  void setTitleAssistant(String assistantId) {
    _userModified = true;
    state = state.copyWith(titleAssistantId: assistantId);
    _persist();
  }

  void setCompactionAssistant(String assistantId) {
    _userModified = true;
    state = state.copyWith(compactionAssistantId: assistantId);
    _persist();
  }
}

// ============================================================================
// 解析：任务助手 → 实际使用的 system prompt
// ============================================================================

/// 解析任务助手的系统提示词。
///
/// [assistantId] 是内置 ID 时返回内置 prompt；是用户助手 ID 时
/// 返回该助手的 prompt；未知/为空时返回 null（调用方跳过该任务）。
String? resolveSystemAssistantPrompt({
  required String? assistantId,
  required List<Assistant> userAssistants,
}) {
  if (assistantId == null || assistantId.isEmpty) return null;
  final builtIn = builtInSystemAssistantById(assistantId);
  if (builtIn != null) return builtIn.prompt;
  final user = userAssistants.where((a) => a.id == assistantId).firstOrNull;
  return user?.prompt;
}

/// 任务助手的显示名称（供设置页选择器使用）。
String systemAssistantDisplayName({
  required String assistantId,
  required List<Assistant> userAssistants,
}) {
  final builtIn = builtInSystemAssistantById(assistantId);
  if (builtIn != null) return '${builtIn.emoji} ${builtIn.name}';
  final user = userAssistants.where((a) => a.id == assistantId).firstOrNull;
  if (user != null) return user.name;
  return '未知助手';
}
