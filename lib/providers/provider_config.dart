import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

// ============================================================================
// 自定义参数
// ============================================================================

class CustomParam {
  String paramName;
  String defaultValue;

  CustomParam({
    required this.paramName,
    this.defaultValue = '',
  });

  Map<String, dynamic> toMap() => {
        'paramName': paramName,
        'defaultValue': defaultValue,
      };

  factory CustomParam.fromMap(Map<String, dynamic> map) => CustomParam(
        paramName: map['paramName'] as String? ?? '',
        defaultValue: map['defaultValue'] as String? ?? '',
      );

  CustomParam copy() => CustomParam(
        paramName: paramName,
        defaultValue: defaultValue,
      );
}

// ============================================================================
// 音色条目
// ============================================================================

class VoiceEntry {
  String name; // 音色名称，如 "标准女生"
  String id;   // 音色ID，如 "female"

  VoiceEntry({
    required this.name,
    this.id = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'id': id,
      };

  factory VoiceEntry.fromMap(Map<String, dynamic> map) => VoiceEntry(
        name: map['name'] as String? ?? '',
        id: map['id'] as String? ?? '',
      );

  VoiceEntry copy() => VoiceEntry(name: name, id: id);
}

// ============================================================================
// 模型配置
// ============================================================================

class ModelConfig {
  String name; // 模型名称
  String modelId; // 模型ID
  List<VoiceEntry> voices; // 音色列表
  double volumeMin; // 音量最小值
  double volumeMax; // 音量最大值
  double speedMin; // 语速最小值
  double speedMax; // 语速最大值
  bool hasVolume; // 是否设置了音量范围
  bool hasSpeed; // 是否设置了语速范围
  List<CustomParam> customParams; // 自定义参数列表
  bool supportStream; // 是否支持流式输出
  String streamUrl; // 流式接口地址（完整URL，如 https://api.example.com/v1/chat/completions）

  ModelConfig({
    required this.name,
    required this.modelId,
    List<VoiceEntry>? voices,
    this.volumeMin = 0.1,
    this.volumeMax = 2.0,
    this.speedMin = 0.5,
    this.speedMax = 2.0,
    this.hasVolume = false,
    this.hasSpeed = false,
    List<CustomParam>? customParams,
    this.supportStream = false,
    this.streamUrl = '',
  })  : voices = voices ?? [],
        customParams = customParams ?? [];

  Map<String, dynamic> toMap() => {
        'name': name,
        'modelId': modelId,
        'voices': voices.map((v) => v.toMap()).toList(),
        'volumeMin': volumeMin,
        'volumeMax': volumeMax,
        'speedMin': speedMin,
        'speedMax': speedMax,
        'hasVolume': hasVolume,
        'hasSpeed': hasSpeed,
        'customParams': customParams.map((p) => p.toMap()).toList(),
        'supportStream': supportStream,
        'streamUrl': streamUrl,
      };

  factory ModelConfig.fromMap(Map<String, dynamic> map) => ModelConfig(
        name: map['name'] as String? ?? '',
        modelId: map['modelId'] as String? ?? '',
        voices: (map['voices'] as List?)
                ?.map((e) => VoiceEntry.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        volumeMin: (map['volumeMin'] as num?)?.toDouble() ?? 0.1,
        volumeMax: (map['volumeMax'] as num?)?.toDouble() ?? 2.0,
        speedMin: (map['speedMin'] as num?)?.toDouble() ?? 0.5,
        speedMax: (map['speedMax'] as num?)?.toDouble() ?? 2.0,
        hasVolume: map['hasVolume'] as bool? ?? false,
        hasSpeed: map['hasSpeed'] as bool? ?? false,
        customParams: (map['customParams'] as List?)
                ?.map((e) => CustomParam.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        supportStream: map['supportStream'] as bool? ?? false,
        streamUrl: map['streamUrl'] as String? ?? '',
      );

  ModelConfig copy() => ModelConfig(
        name: name,
        modelId: modelId,
        voices: voices.map((v) => v.copy()).toList(),
        volumeMin: volumeMin,
        volumeMax: volumeMax,
        speedMin: speedMin,
        speedMax: speedMax,
        hasVolume: hasVolume,
        hasSpeed: hasSpeed,
        customParams: customParams.map((p) => p.copy()).toList(),
        supportStream: supportStream,
        streamUrl: streamUrl,
      );
}

// ============================================================================
// 供应商配置项（一个供应商条目下可以有多个配置）
// ============================================================================

class ProviderConfigItem {
  String providerName;
  String host;
  String key;
  List<ModelConfig> models;

  ProviderConfigItem({
    this.providerName = '',
    this.host = '',
    this.key = '',
    List<ModelConfig>? models,
  }) : models = models ?? [];

  Map<String, dynamic> toMap() => {
        'providerName': providerName,
        'host': host,
        'key': key,
        'models': models.map((m) => m.toMap()).toList(),
      };

  factory ProviderConfigItem.fromMap(Map<String, dynamic> map) =>
      ProviderConfigItem(
        providerName: map['providerName'] as String? ?? '',
        host: map['host'] as String? ?? '',
        key: map['key'] as String? ?? '',
        models: (map['models'] as List?)
                ?.map((e) =>
                    ModelConfig.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );

  ProviderConfigItem copy() => ProviderConfigItem(
        providerName: providerName,
        host: host,
        key: key,
        models: models.map((m) => m.copy()).toList(),
      );
}

// ============================================================================
// 供应商条目（设置页面的列表项）
// ============================================================================

class ProviderEntry {
  final String id;
  String name; // 显示名称，如 "TTS供应商"
  List<ProviderConfigItem> configs;

  ProviderEntry({
    String? id,
    required this.name,
    List<ProviderConfigItem>? configs,
  })  : id = id ?? 'provider_${const Uuid().v4()}',
        configs = configs ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'configs': configs.map((c) => c.toMap()).toList(),
      };

  factory ProviderEntry.fromMap(Map<String, dynamic> map) {
    // 新格式
    if (map.containsKey('configs')) {
      return ProviderEntry(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        configs: (map['configs'] as List?)
                ?.map((e) => ProviderConfigItem.fromMap(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
    }
    // 旧格式兼容：迁移到 configs[0]
    final config = ProviderConfigItem(
      providerName: map['providerName'] as String? ?? '',
      host: map['host'] as String? ?? '',
      key: map['key'] as String? ?? '',
      models: (map['models'] as List?)
              ?.map((e) =>
                  ModelConfig.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
    return ProviderEntry(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      configs: config.providerName.isEmpty &&
              config.host.isEmpty &&
              config.key.isEmpty
          ? []
          : [config],
    );
  }
}

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
      final json = prefs.getString('provider_entries');
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        final entries = list.map((m) => ProviderEntry.fromMap(m)).toList();
        state = ProviderEntriesState(entries: entries);
        return;
      }
    } catch (e) {
      print('Failed to load provider entries: $e');
    }

    // 默认预置 TTS供应商
    state = ProviderEntriesState(entries: [
      ProviderEntry(
        id: 'builtin_tts',
        name: 'TTS供应商',
      ),
    ]);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.entries.map((e) => e.toMap()).toList());
      await prefs.setString('provider_entries', json);
    } catch (e) {
      print('Failed to persist provider entries: $e');
    }
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
