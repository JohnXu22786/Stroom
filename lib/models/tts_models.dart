import 'package:uuid/uuid.dart';

// ============================================================================
// 参数类型枚举
// ============================================================================

class ParamType {
  final String value;
  final String label;

  const ParamType._(this.value, this.label);

  static const string = ParamType._('string', '字符串');
  static const number = ParamType._('number', '数字');
  static const boolean = ParamType._('boolean', '布尔');

  static const List<ParamType> values = [string, number, boolean];

  static ParamType fromValue(String? value) {
    return values.firstWhere(
      (t) => t.value == value,
      orElse: () => string,
    );
  }

  bool get needsQuotes => this == string;

  String get defaultValueHint {
    switch (this) {
      case ParamType.string:
        return '例如: cheerful';
      case ParamType.number:
        return '例如: 0.8';
      case ParamType.boolean:
        return '例如: true';
      default:
        return '';
    }
  }

  @override
  bool operator ==(Object other) => other is ParamType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

// ============================================================================
// 自定义参数
// ============================================================================

class CustomParam {
  String paramName;
  String defaultValue;
  String type;

  CustomParam({
    required this.paramName,
    this.defaultValue = '',
    this.type = 'string',
  });

  ParamType get paramType => ParamType.fromValue(type);

  Map<String, dynamic> toMap() => {
        'paramName': paramName,
        'defaultValue': defaultValue,
        'type': type,
      };

  factory CustomParam.fromMap(Map<String, dynamic> map) => CustomParam(
        paramName: map['paramName'] as String? ?? '',
        defaultValue: map['defaultValue'] as String? ?? '',
        type: map['type'] as String? ?? 'string',
      );

  CustomParam copy() => CustomParam(
        paramName: paramName,
        defaultValue: defaultValue,
        type: type,
      );
}

// ============================================================================
// 裁切预设
// ============================================================================

enum TrimDirection {
  head('head', '裁切开头'),
  tail('tail', '裁切结尾');

  final String value;
  final String label;
  const TrimDirection(this.value, this.label);

  static TrimDirection fromValue(String? value) {
    return TrimDirection.values.firstWhere(
      (d) => d.value == value,
      orElse: () => TrimDirection.head,
    );
  }
}

class TrimPreset {
  String id;
  String name;
  double durationSeconds;
  String direction;

  TrimPreset({
    String? id,
    required this.name,
    required this.durationSeconds,
    this.direction = 'head',
  }) : id = id ?? 'trim_${const Uuid().v4()}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'durationSeconds': durationSeconds,
        'direction': direction,
      };

  factory TrimPreset.fromMap(Map<String, dynamic> map) => TrimPreset(
        id: map['id'] as String?,
        name: map['name'] as String? ?? '',
        durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0,
        direction: map['direction'] as String? ?? 'head',
      );

  TrimPreset copy() => TrimPreset(
        id: id,
        name: name,
        durationSeconds: durationSeconds,
        direction: direction,
      );
}

// ============================================================================
// 音色条目
// ============================================================================

class VoiceEntry {
  String name;
  String id;

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
// 推理参数
// ============================================================================

class ReasoningParam {
  String paramName;

  List<String> options;

  bool enabled;

  bool isReasoningToggle;

  String? onValue;

  String? offValue;

  ReasoningParam({
    required this.paramName,
    this.enabled = true,
    this.isReasoningToggle = false,
    this.onValue,
    this.offValue,
    List<String>? options,
  }) : options = options ?? [];

  Map<String, dynamic> toMap() => {
        'paramName': paramName,
        'options': options,
        'enabled': enabled,
        'isReasoningToggle': isReasoningToggle,
        if (onValue != null) 'onValue': onValue,
        if (offValue != null) 'offValue': offValue,
      };

  factory ReasoningParam.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('defaultValue') && !map.containsKey('options')) {
      return ReasoningParam(
        paramName: map['paramName'] as String? ?? '',
        options: [],
      );
    }
    return ReasoningParam(
      paramName: map['paramName'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      isReasoningToggle: map['isReasoningToggle'] as bool? ?? false,
      onValue: map['onValue'] as String?,
      offValue: map['offValue'] as String?,
      options: (map['options'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  ReasoningParam copy() => ReasoningParam(
        paramName: paramName,
        enabled: enabled,
        isReasoningToggle: isReasoningToggle,
        onValue: onValue,
        offValue: offValue,
        options: List<String>.from(options),
      );

  bool get isFilledToggle {
    if (!isReasoningToggle) return false;
    return paramName.trim().isNotEmpty &&
        (onValue != null && onValue!.trim().isNotEmpty) &&
        (offValue != null && offValue!.trim().isNotEmpty);
  }

  String? get validationError {
    if (isReasoningToggle) {
      final nameTrimmed = paramName.trim();
      final hasOnValue = onValue != null && onValue!.trim().isNotEmpty;
      final hasOffValue = offValue != null && offValue!.trim().isNotEmpty;

      if (nameTrimmed.isEmpty && !hasOnValue && !hasOffValue) return null;

      if (nameTrimmed.isEmpty) return '推理开关参数名不能为空';
      if (!hasOnValue) return '推理开关开启值不能为空';
      if (!hasOffValue) return '推理开关关闭值不能为空';

      return null;
    }
    if (paramName.trim().isEmpty) return '参数名不能为空';
    for (int j = 0; j < options.length; j++) {
      if (options[j].trim().isEmpty) {
        return '选项值不能为空';
      }
    }
    return null;
  }
}

// ============================================================================
// 模型配置
// ============================================================================

class ModelConfig {
  String name;
  String modelId;
  List<VoiceEntry> voices;
  double volumeMin;
  double volumeMax;
  double speedMin;
  double speedMax;
  bool hasVolume;
  bool hasSpeed;
  List<CustomParam> customParams;
  List<ReasoningParam> reasoningParams;
  int maxWordsPerRequest;
  bool supportStream;
  bool supportInstruction;
  Map<String, dynamic> typeConfig;
  String? selectedTrimPresetId;

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
    List<ReasoningParam>? reasoningParams,
    this.maxWordsPerRequest = 0,
    this.supportStream = false,
    this.supportInstruction = false,
    this.typeConfig = const {},
    this.selectedTrimPresetId,
  })  : voices = voices ?? [],
        customParams = customParams ?? [],
        reasoningParams = reasoningParams ?? [];

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
        'reasoningParams': reasoningParams.map((p) => p.toMap()).toList(),
        'maxWordsPerRequest': maxWordsPerRequest,
        'supportStream': supportStream,
        'supportInstruction': supportInstruction,
        'typeConfig': typeConfig,
        'selectedTrimPresetId': selectedTrimPresetId,
      };

  factory ModelConfig.fromMap(Map<String, dynamic> map) => ModelConfig(
        name: map['name'] as String? ?? '',
        modelId: map['modelId'] as String? ?? '',
        voices: (map['voices'] as List?)
                ?.map((e) =>
                    VoiceEntry.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        volumeMin: (map['volumeMin'] as num?)?.toDouble() ?? 0.1,
        volumeMax: (map['volumeMax'] as num?)?.toDouble() ?? 2.0,
        speedMin: (map['speedMin'] as num?)?.toDouble() ?? 0.5,
        speedMax: (map['speedMax'] as num?)?.toDouble() ?? 2.0,
        hasVolume: map['hasVolume'] as bool? ?? false,
        hasSpeed: map['hasSpeed'] as bool? ?? false,
        customParams: (map['customParams'] as List?)
                ?.map((e) =>
                    CustomParam.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        reasoningParams: (map['reasoningParams'] as List?)
                ?.map((e) =>
                    ReasoningParam.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        maxWordsPerRequest: (map['maxWordsPerRequest'] as num?)?.toInt() ?? 0,
        supportStream: map['supportStream'] as bool? ?? false,
        supportInstruction: map['supportInstruction'] == true,
        typeConfig: Map<String, dynamic>.from(map['typeConfig'] as Map? ?? {}),
        selectedTrimPresetId: map['selectedTrimPresetId'] as String?,
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
        reasoningParams: reasoningParams.map((p) => p.copy()).toList(),
        maxWordsPerRequest: maxWordsPerRequest,
        supportStream: supportStream,
        supportInstruction: supportInstruction,
        selectedTrimPresetId: selectedTrimPresetId,
        typeConfig: Map<String, dynamic>.from(typeConfig),
      );
}

// ============================================================================
// 供应商配置项
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
// 供应商条目
// ============================================================================

class ProviderEntry {
  final String id;
  String type;
  String name;
  List<ProviderConfigItem> configs;

  ProviderEntry({
    String? id,
    this.type = 'tts',
    required this.name,
    List<ProviderConfigItem>? configs,
  })  : id = id ?? 'provider_${const Uuid().v4()}',
        configs = configs ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'configs': configs.map((c) => c.toMap()).toList(),
      };

  factory ProviderEntry.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('configs')) {
      return ProviderEntry(
        id: map['id'] as String,
        type: map['type'] as String? ?? 'tts',
        name: map['name'] as String? ?? '',
        configs: (map['configs'] as List?)
                ?.map((e) => ProviderConfigItem.fromMap(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
    }
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
      type: map['type'] as String? ?? 'tts',
      name: map['name'] as String? ?? '',
      configs: config.providerName.isEmpty &&
              config.host.isEmpty &&
              config.key.isEmpty
          ? []
          : [config],
    );
  }
}
