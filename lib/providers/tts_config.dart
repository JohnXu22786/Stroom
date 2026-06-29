import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'provider_config.dart';

// ============================================================================
// 供应商注册表 — 支持动态注册，替换旧的 TTSProvider 枚举
// ============================================================================

/// 模型定义：描述一个 TTS 模型的信息
class ModelInfo {
  final String name;
  final List<String> voices;
  final double speedMin;
  final double speedMax;
  final double volumeMin;
  final double volumeMax;

  const ModelInfo({
    required this.name,
    this.voices = const [],
    this.speedMin = 0.5,
    this.speedMax = 2.0,
    this.volumeMin = 0.0,
    this.volumeMax = 2.0,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'voices': voices,
        'speedMin': speedMin,
        'speedMax': speedMax,
        'volumeMin': volumeMin,
        'volumeMax': volumeMax,
      };

  factory ModelInfo.fromMap(Map<String, dynamic> map) => ModelInfo(
        name: map['name'] as String,
        voices: (map['voices'] as List?)?.cast<String>() ?? [],
        speedMin: (map['speedMin'] as num?)?.toDouble() ?? 0.5,
        speedMax: (map['speedMax'] as num?)?.toDouble() ?? 2.0,
        volumeMin: (map['volumeMin'] as num?)?.toDouble() ?? 0.0,
        volumeMax: (map['volumeMax'] as num?)?.toDouble() ?? 2.0,
      );
}

/// 供应商定义：描述一个 TTS 供应商的全部元信息
class TTSProviderDefinition {
  final String id; // 唯一标识，如 'glm_tts'
  final String label; // 显示名称，如 'GLM-TTS'
  final String? defaultBaseUrl;
  final List<String> supportedVoices;
  final List<String> supportedFormats;
  final List<ModelInfo> supportedModels;
  final double speedMin;
  final double speedMax;
  final double volumeMin;
  final double volumeMax;
  final int defaultSampleRate;
  final Map<String, dynamic> defaultConfig; // 供应商专属默认值（apiKey 等留空）

  const TTSProviderDefinition({
    required this.id,
    required this.label,
    this.defaultBaseUrl,
    this.supportedVoices = const [],
    this.supportedFormats = const ['wav', 'pcm'],
    this.supportedModels = const [],
    this.speedMin = 0.5,
    this.speedMax = 2.0,
    this.volumeMin = 0.0,
    this.volumeMax = 2.0,
    this.defaultSampleRate = 24000,
    this.defaultConfig = const {},
  });

  /// 转 Map（用于持久化）
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'defaultBaseUrl': defaultBaseUrl,
        'supportedVoices': supportedVoices,
        'supportedFormats': supportedFormats,
        'supportedModels': supportedModels.map((m) => m.toMap()).toList(),
        'speedMin': speedMin,
        'speedMax': speedMax,
        'volumeMin': volumeMin,
        'volumeMax': volumeMax,
        'defaultSampleRate': defaultSampleRate,
        'defaultConfig': defaultConfig,
      };

  /// 从 Map 构造
  factory TTSProviderDefinition.fromMap(Map<String, dynamic> map) {
    return TTSProviderDefinition(
      id: map['id'] as String,
      label: map['label'] as String,
      defaultBaseUrl: map['defaultBaseUrl'] as String?,
      supportedVoices: (map['supportedVoices'] as List?)?.cast<String>() ?? [],
      supportedFormats:
          (map['supportedFormats'] as List?)?.cast<String>() ?? ['wav', 'pcm'],
      supportedModels: map['supportedModels'] is List
          ? (map['supportedModels'] as List)
              .map(
                  (m) => ModelInfo.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList()
          : [],
      speedMin: (map['speedMin'] as num?)?.toDouble() ?? 0.5,
      speedMax: (map['speedMax'] as num?)?.toDouble() ?? 2.0,
      volumeMin: (map['volumeMin'] as num?)?.toDouble() ?? 0.0,
      volumeMax: (map['volumeMax'] as num?)?.toDouble() ?? 2.0,
      defaultSampleRate: (map['defaultSampleRate'] as num?)?.toInt() ?? 24000,
      defaultConfig:
          Map<String, dynamic>.from(map['defaultConfig'] as Map? ?? {}),
    );
  }
}

/// 供应商注册表
class TTSProviderRegistry {
  static final Map<String, TTSProviderDefinition> _registry = {};

  /// 注册一个供应商
  static void register(TTSProviderDefinition def) {
    _registry[def.id] = def;
  }

  /// 通过 id 获取定义
  static TTSProviderDefinition? get(String id) => _registry[id];

  /// 获取所有已注册的供应商
  static List<TTSProviderDefinition> getAll() =>
      _registry.values.toList(growable: false);

  /// 是否已注册
  static bool isRegistered(String id) => _registry.containsKey(id);

  /// 注销（用于测试）
  static void unregister(String id) => _registry.remove(id);
}

// ============================================================================
// 自定义供应商定义（用户自定义）
// ============================================================================

/// 用户自定义供应商的完整定义（持久化用）
///
/// 仅包含供应商级信息（标识、名称、端点 URL）。
/// 模型信息在供应商配置页面中单独管理。
class CustomProviderDefinition {
  final String id;
  final String label;
  final String baseUrl;

  const CustomProviderDefinition({
    required this.id,
    required this.label,
    required this.baseUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'baseUrl': baseUrl,
      };

  factory CustomProviderDefinition.fromMap(Map<String, dynamic> map) {
    return CustomProviderDefinition(
      id: map['id'] as String,
      label: map['label'] as String,
      baseUrl: map['baseUrl'] as String? ?? '',
    );
  }

  /// 注册到全局注册表
  ///
  /// 模型信息在供应商配置页面中单独管理，
  /// 此处仅注册供应商级信息。
  void register() {
    TTSProviderRegistry.register(TTSProviderDefinition(
      id: id,
      label: label,
      defaultBaseUrl: baseUrl,
      supportedVoices: [],
      supportedModels: [],
      defaultConfig: {},
    ));
  }
}

// ============================================================================
// 内置供应商注册
// ============================================================================

/// 在模块加载时注册所有内置供应商
/// 当前不内置任何供应商，所有供应商由用户在配置页面添加
void registerBuiltinProviders() {
  // 不注册任何内置供应商
}

// ============================================================================
// 全局配置工具函数（基于注册表）
// ============================================================================

/// 获取指定供应商的音色列表
List<String> getSupportedVoices(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  return def != null ? List.from(def.supportedVoices) : [];
}

/// 获取指定供应商的格式列表
List<String> getSupportedFormats(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  return def != null ? List.from(def.supportedFormats) : [];
}

/// 获取指定供应商的语速范围
Map<String, double> getSpeedRange(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  if (def == null) return {'min': 0.5, 'max': 2.0};
  return {'min': def.speedMin, 'max': def.speedMax};
}

/// 获取指定供应商的音量范围
Map<String, double> getVolumeRange(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  if (def == null) return {'min': 0.0, 'max': 2.0};
  return {'min': def.volumeMin, 'max': def.volumeMax};
}

/// 验证语速
bool validateSpeed(String providerId, double speed) {
  final range = getSpeedRange(providerId);
  return speed >= range['min']! && speed <= range['max']!;
}

/// 验证音量
bool validateVolume(String providerId, double volume) {
  final range = getVolumeRange(providerId);
  return volume >= range['min']! && volume <= range['max']!;
}

/// 检查供应商是否受支持
bool isProviderSupported(String providerId) {
  return TTSProviderRegistry.isRegistered(providerId);
}

// ============================================================================
// 裁切预设系统
// ============================================================================

/// 内置裁切预设 ID 常量
class BuiltinTrimPresetIds {
  static const String none = 'builtin_none';
  static const String beep = 'builtin_beep';
  static const String buzzer = 'builtin_buzzer';
}

/// 获取内置裁切预设列表
List<Map<String, dynamic>> getBuiltinTrimPresets() {
  return [
    {
      'id': BuiltinTrimPresetIds.none,
      'name': '不裁切',
      'durationSeconds': 0.0,
      'direction': 'head',
    },
    {
      'id': BuiltinTrimPresetIds.beep,
      'name': '滴滴声 (0.630s)',
      'durationSeconds': 0.63,
      'direction': 'head',
    },
    {
      'id': BuiltinTrimPresetIds.buzzer,
      'name': '嘟嘟声 (1.830s)',
      'durationSeconds': 1.83,
      'direction': 'head',
    },
  ];
}

// ============================================================================
// 自定义裁切预设全局状态
// ============================================================================

/// 自定义裁切预设列表提供器（持久化）
final customTrimPresetsProvider =
    StateNotifierProvider<CustomTrimPresetsNotifier, List<TrimPreset>>((ref) {
  final notifier = CustomTrimPresetsNotifier();
  notifier.load();
  return notifier;
});

class CustomTrimPresetsNotifier extends StateNotifier<List<TrimPreset>> {
  CustomTrimPresetsNotifier() : super([]);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('custom_trim_presets');
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        state = list.map((m) => TrimPreset.fromMap(m)).toList();
        return;
      }
    } catch (e) {
      debugPrint('Failed to load custom trim presets: $e');
    }
    state = [];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((e) => e.toMap()).toList());
      await prefs.setString('custom_trim_presets', json);
    } catch (e) {
      debugPrint('Failed to persist custom trim presets: $e');
    }
  }

  /// 添加一个自定义裁切预设
  Future<void> add(TrimPreset preset) async {
    state = [...state, preset];
    await _persist();
  }

  /// 更新一个自定义裁切预设
  Future<void> update(String id, TrimPreset updated) async {
    state = state.map((e) => e.id == id ? updated : e).toList();
    await _persist();
  }

  /// 删除一个自定义裁切预设
  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
  }
}

/// 获取所有裁切预设（内置+自定义），返回 Map，key 为 preset ID
List<Map<String, dynamic>> getAllTrimPresets(List<TrimPreset> customPresets) {
  final builtin = getBuiltinTrimPresets();
  final all = <Map<String, dynamic>>[...builtin];
  for (final cp in customPresets) {
    all.add({
      'id': cp.id,
      'name': cp.name,
      'durationSeconds': cp.durationSeconds,
      'direction': cp.direction,
      'isCustom': true,
    });
  }
  return all;
}

/// 根据 ID 获取裁切预设详情（内置+自定义）
Map<String, dynamic>? getTrimPresetById(
    String id, List<TrimPreset> customPresets) {
  // 在内置中查找
  for (final builtin in getBuiltinTrimPresets()) {
    if (builtin['id'] == id) return builtin;
  }
  // 在自定义中查找
  for (final cp in customPresets) {
    if (cp.id == id) {
      return {
        'id': cp.id,
        'name': cp.name,
        'durationSeconds': cp.durationSeconds,
        'direction': cp.direction,
        'isCustom': true,
      };
    }
  }
  return null;
}
