import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// 上下文管理设置
// ============================================================================
//
// 压缩触发设置（面板内配置）：
// - 总开关 compactionEnabled：关闭后所有模型都不触发压缩
// - 全局百分比 globalCompactionPercent：模型未单独设置时，
//   在模型上下文窗口的该百分比处触发压缩
// - 逐模型设置 perModelCompaction：模型开启独立值后用具体 token 数触发，
//   关闭则跟随全局百分比
//
// 旧版"自定义压缩触发值"（单值 token 阈值）被上述模型取代，
// 对应的持久化 key 在 _load 时清理。
// ============================================================================

const String _kPruneEnabledKey = 'context_prune_enabled';
const String _kCompactionEnabledKey = 'context_compaction_enabled';
const String _kGlobalCompactionPercentKey = 'context_compaction_global_percent';
const String _kPerModelCompactionKey = 'context_compaction_per_model';

/// 旧版"自定义压缩触发值"的持久化 key（已被新格式取代，加载时清理）。
const String _kLegacyCompactionThresholdEnabledKey =
    'context_compaction_threshold_enabled';
const String _kLegacyCompactionThresholdKey = 'context_compaction_threshold';

/// 全局压缩触发百分比默认值。
const int kDefaultCompactionPercent = 95;

/// 模型独立压缩触发值下限（token）。过小会导致每次发送都触发压缩。
const int kMinCompactionThreshold = 1000;

/// 构建按模型定位的持久化 key：优先 (providerName, modelId) 复合键
/// （对齐应用其余部分的绝对身份定义），供应商名缺失时退化为 modelId
/// （旧数据 / 无供应商配置的测试环境）。modelId 缺失时返回空串（无效）。
String compactionModelKey({String? modelId, String? providerName}) {
  final id = (modelId ?? '').trim();
  if (id.isEmpty) return '';
  final provider = (providerName ?? '').trim();
  if (provider.isEmpty) return id;
  return '$provider\u0000$id';
}

/// 单个模型的独立压缩设置（map key = [compactionModelKey]）。
class PerModelCompactionConfig {
  /// 是否使用该模型的独立触发值（否则跟随全局百分比）。
  final bool enabled;

  /// 独立触发值（token 数，**非百分比**）。仅 [enabled] 时生效；
  /// null 表示未填写（跟随全局百分比）。
  final int? threshold;

  const PerModelCompactionConfig({this.enabled = false, this.threshold});

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        if (threshold != null) 'threshold': threshold,
      };

  factory PerModelCompactionConfig.fromMap(Map<String, dynamic> map) =>
      PerModelCompactionConfig(
        enabled: map['enabled'] as bool? ?? false,
        threshold: (map['threshold'] as num?)?.toInt(),
      );
}

class ContextManagementSettings {
  /// 工具结果 prune 开关（默认开：旧工具结果超阈值时自动软删除）。
  final bool pruneEnabled;

  /// 上下文自动压缩总开关（默认开）。关闭后所有模型都不触发压缩。
  final bool compactionEnabled;

  /// 全局压缩触发百分比（默认 [kDefaultCompactionPercent]）。
  /// 模型未单独设置时，在模型上下文窗口的该百分比处触发压缩。
  final int globalCompactionPercent;

  /// 各模型的独立压缩设置（key = [compactionModelKey]，
  /// 由 (providerName, modelId) 构成，避免不同供应商的同名模型互相覆盖）。
  final Map<String, PerModelCompactionConfig> perModelCompaction;

  const ContextManagementSettings({
    this.pruneEnabled = true,
    this.compactionEnabled = true,
    this.globalCompactionPercent = kDefaultCompactionPercent,
    this.perModelCompaction = const {},
  });

  ContextManagementSettings copyWith({
    bool? pruneEnabled,
    bool? compactionEnabled,
    int? globalCompactionPercent,
    Map<String, PerModelCompactionConfig>? perModelCompaction,
  }) =>
      ContextManagementSettings(
        pruneEnabled: pruneEnabled ?? this.pruneEnabled,
        compactionEnabled: compactionEnabled ?? this.compactionEnabled,
        globalCompactionPercent:
            globalCompactionPercent ?? this.globalCompactionPercent,
        perModelCompaction: perModelCompaction ?? this.perModelCompaction,
      );

  /// 某模型的独立压缩设置（key = [compactionModelKey]）；未配置返回 null。
  PerModelCompactionConfig? perModelConfig(String? modelKey) =>
      (modelKey == null || modelKey.isEmpty)
          ? null
          : perModelCompaction[modelKey];

  /// 有效的压缩触发线（token 数）；null 表示不触发压缩。
  ///
  /// 规则：
  /// - 总开关关闭 → 不触发（null）
  /// - 模型没有上下文配置 → 不触发（null）
  /// - 模型启用独立触发值且已填写 → 用该值（超过模型窗口时钳制到窗口）
  /// - 其余（模型未单独设置 / 开启但未填值）→ 全局百分比 × 模型上下文
  int? effectiveCompactionThreshold(int? modelContext, {String? modelKey}) {
    if (!compactionEnabled) return null;
    if (modelContext == null || modelContext <= 0) return null;
    final perModel = perModelConfig(modelKey);
    if (perModel != null && perModel.enabled) {
      final threshold = perModel.threshold;
      if (threshold != null) {
        return threshold <= modelContext ? threshold : modelContext;
      }
    }
    return (modelContext * _clampPercent(globalCompactionPercent) / 100)
        .floor();
  }

  static int _clampPercent(int percent) =>
      percent < 1 ? 1 : (percent > 100 ? 100 : percent);
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
      // 清理旧版"自定义压缩触发值" key（新格式取代，幂等）。
      await prefs.remove(_kLegacyCompactionThresholdEnabledKey);
      await prefs.remove(_kLegacyCompactionThresholdKey);
      if (_userModified) return;
      state = ContextManagementSettings(
        pruneEnabled: prefs.getBool(_kPruneEnabledKey) ?? true,
        compactionEnabled: prefs.getBool(_kCompactionEnabledKey) ?? true,
        globalCompactionPercent: ContextManagementSettings._clampPercent(
            prefs.getInt(_kGlobalCompactionPercentKey) ??
                kDefaultCompactionPercent),
        perModelCompaction:
            _decodePerModelCompaction(prefs.getString(_kPerModelCompactionKey)),
      );
    } catch (e) {
      debugPrint('Failed to load context management settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPruneEnabledKey, state.pruneEnabled);
      await prefs.setBool(_kCompactionEnabledKey, state.compactionEnabled);
      await prefs.setInt(
          _kGlobalCompactionPercentKey, state.globalCompactionPercent);
      await prefs.setString(
          _kPerModelCompactionKey,
          jsonEncode({
            for (final e in state.perModelCompaction.entries)
              e.key: e.value.toMap(),
          }));
    } catch (e) {
      debugPrint('Failed to persist context management settings: $e');
    }
  }

  static Map<String, PerModelCompactionConfig> _decodePerModelCompaction(
      String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      final result = <String, PerModelCompactionConfig>{};
      decoded.forEach((key, value) {
        if (value is Map) {
          result[key.toString()] = PerModelCompactionConfig.fromMap(
              Map<String, dynamic>.from(value));
        }
      });
      return result;
    } catch (e) {
      debugPrint('Failed to decode per-model compaction settings: $e');
      return const {};
    }
  }

  /// 设置方法返回 Future（内部等待持久化完成），便于测试与串行化；
  /// UI 调用处可不 await（返回值被忽略）。
  Future<void> setPruneEnabled(bool enabled) {
    _userModified = true;
    state = state.copyWith(pruneEnabled: enabled);
    return _persist();
  }

  /// 上下文自动压缩总开关。
  Future<void> setCompactionEnabled(bool enabled) {
    _userModified = true;
    state = state.copyWith(compactionEnabled: enabled);
    return _persist();
  }

  /// 全局压缩触发百分比（范围 1–100，越界钳制）。
  Future<void> setGlobalCompactionPercent(int percent) {
    _userModified = true;
    state = state.copyWith(
      globalCompactionPercent:
          percent < 1 ? 1 : (percent > 100 ? 100 : percent),
    );
    return _persist();
  }

  /// 一键重置全局百分比回默认值 [kDefaultCompactionPercent]。
  Future<void> resetGlobalCompactionPercent() {
    _userModified = true;
    state = state.copyWith(globalCompactionPercent: kDefaultCompactionPercent);
    return _persist();
  }

  /// 设置某模型的独立压缩开关（modelKey = [compactionModelKey]）。
  /// 关闭后保留已填写的值但不再生效（跟随全局）；重新开启时值恢复。
  Future<void> setPerModelEnabled(String modelKey, bool enabled) {
    _userModified = true;
    final updated =
        Map<String, PerModelCompactionConfig>.of(state.perModelCompaction);
    final current = updated[modelKey];
    updated[modelKey] = PerModelCompactionConfig(
      enabled: enabled,
      threshold: current?.threshold,
    );
    state = state.copyWith(perModelCompaction: updated);
    return _persist();
  }

  /// 设置某模型的独立触发值（modelKey = [compactionModelKey]，
  /// token，需 ≥ [kMinCompactionThreshold]）。
  /// 清空/无效值 → 独立值置空（回退全局百分比），但**保留开关状态**：
  /// 误清输入不应同时关闭模型的独立设置（开关由 [setPerModelEnabled] 控制）。
  Future<void> setPerModelThreshold(String modelKey, int? threshold) {
    _userModified = true;
    final updated =
        Map<String, PerModelCompactionConfig>.of(state.perModelCompaction);
    final current = updated[modelKey];
    if (threshold == null || threshold < kMinCompactionThreshold) {
      // 从未配置（无开关状态可保留）→ 无操作；否则仅清空值。
      if (current != null) {
        updated[modelKey] = PerModelCompactionConfig(
          enabled: current.enabled,
          threshold: null,
        );
      }
    } else {
      updated[modelKey] = PerModelCompactionConfig(
        enabled: current?.enabled ?? true,
        threshold: threshold,
      );
    }
    state = state.copyWith(perModelCompaction: updated);
    return _persist();
  }
}
