import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// 上下文管理设置
// ============================================================================
//
// 参照 opencode 的 compaction 配置：
// - prune：工具结果自动清理开关（opencode compaction.prune）
// - 压缩触发值：默认到达模型设置的上下文窗口即压缩；
//   可自定义一个更小的触发值（opencode compaction.reserved 类似语义，
//   但以"显式阈值"表达）
// ============================================================================

const String _kPruneEnabledKey = 'context_prune_enabled';
const String _kCompactionThresholdEnabledKey =
    'context_compaction_threshold_enabled';
const String _kCompactionThresholdKey = 'context_compaction_threshold';

class ContextManagementSettings {
  /// 工具结果 prune 开关（默认开：旧工具结果超阈值时自动软删除）。
  final bool pruneEnabled;

  /// 是否启用自定义压缩触发值（关闭时使用模型设置的上下文窗口）。
  final bool customCompactionThresholdEnabled;

  /// 自定义压缩触发值（token 数）。仅在 [customCompactionThresholdEnabled]
  /// 时生效；null 表示未设置（使用模型上下文）。
  final int? compactionThreshold;

  const ContextManagementSettings({
    this.pruneEnabled = true,
    this.customCompactionThresholdEnabled = false,
    this.compactionThreshold,
  });

  ContextManagementSettings copyWith({
    bool? pruneEnabled,
    bool? customCompactionThresholdEnabled,
    int? compactionThreshold,
  }) =>
      ContextManagementSettings(
        pruneEnabled: pruneEnabled ?? this.pruneEnabled,
        customCompactionThresholdEnabled: customCompactionThresholdEnabled ??
            this.customCompactionThresholdEnabled,
        compactionThreshold: compactionThreshold ?? this.compactionThreshold,
      );

  /// 清除自定义压缩触发值（回到"用模型上下文"）。
  ContextManagementSettings clearCompactionThreshold() =>
      ContextManagementSettings(
        pruneEnabled: pruneEnabled,
        customCompactionThresholdEnabled: customCompactionThresholdEnabled,
        compactionThreshold: null,
      );

  /// 有效的压缩触发线（token 数）。
  /// 自定义启用且有值时用之；否则返回模型上下文（null 表示无上下文配置）。
  int? effectiveCompactionThreshold(int? modelContext) {
    if (customCompactionThresholdEnabled && compactionThreshold != null) {
      return compactionThreshold;
    }
    return modelContext;
  }
}

final contextManagementSettingsProvider = StateNotifierProvider<
    ContextManagementSettingsNotifier, ContextManagementSettings>((ref) {
  final notifier = ContextManagementSettingsNotifier();
  notifier._load();
  return notifier;
});

class ContextManagementSettingsNotifier
    extends StateNotifier<ContextManagementSettings> {
  ContextManagementSettingsNotifier()
      : super(const ContextManagementSettings());

  /// 用户是否已修改过设置（set 方法被调用过）。
  /// 为 true 时 [_load] 不再覆盖（避免异步加载覆盖用户快速修改）。
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userModified) return;
      final threshold = prefs.getInt(_kCompactionThresholdKey);
      state = ContextManagementSettings(
        pruneEnabled: prefs.getBool(_kPruneEnabledKey) ?? true,
        customCompactionThresholdEnabled:
            prefs.getBool(_kCompactionThresholdEnabledKey) ?? false,
        compactionThreshold: threshold,
      );
    } catch (e) {
      debugPrint('Failed to load context management settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPruneEnabledKey, state.pruneEnabled);
      await prefs.setBool(_kCompactionThresholdEnabledKey,
          state.customCompactionThresholdEnabled);
      final threshold = state.compactionThreshold;
      if (threshold != null) {
        await prefs.setInt(_kCompactionThresholdKey, threshold);
      } else {
        await prefs.remove(_kCompactionThresholdKey);
      }
    } catch (e) {
      debugPrint('Failed to persist context management settings: $e');
    }
  }

  /// 设置方法返回 Future（内部等待持久化完成），便于测试与串行化；
  /// UI 调用处可不 await（返回值被忽略）。
  Future<void> setPruneEnabled(bool enabled) {
    _userModified = true;
    state = state.copyWith(pruneEnabled: enabled);
    return _persist();
  }

  Future<void> setCustomCompactionThresholdEnabled(bool enabled) {
    _userModified = true;
    state = state.copyWith(customCompactionThresholdEnabled: enabled);
    return _persist();
  }

  Future<void> setCompactionThreshold(int? threshold) {
    _userModified = true;
    state = threshold == null
        ? state.clearCompactionThreshold()
        : state.copyWith(compactionThreshold: threshold);
    return _persist();
  }
}
