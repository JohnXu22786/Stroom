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
  static const json = ParamType._('json', 'JSON');

  static const List<ParamType> values = [string, number, boolean, json];

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
      case ParamType.json:
        return '例如: {"key": "value"}';
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

  /// True if this param is the dedicated inference intensity/effort param
  /// (推理力度). Only one param in a model should have this set to true.
  bool isEffortParam;

  /// Whether the persisted data explicitly contained the `isEffortParam`
  /// key. Data saved before the flag existed (legacy) has it absent —
  /// in that era the effort param was identified by position (first
  /// non-toggle param). Used by [findEffortParam] to distinguish legacy
  /// data from modern data that deliberately has no effort param.
  /// Code-constructed params default to true (modern semantics).
  /// This is a derivation marker and is NOT serialized by [toMap].
  final bool hasExplicitEffortFlag;

  String? onValue;

  String? offValue;

  String type; // 'string', 'number', 'boolean', 'json'

  ReasoningParam({
    required this.paramName,
    this.enabled = true,
    this.isReasoningToggle = false,
    this.isEffortParam = false,
    this.hasExplicitEffortFlag = true,
    this.onValue,
    this.offValue,
    List<String>? options,
    this.type = 'string',
  }) : options = options ?? [];

  Map<String, dynamic> toMap() => {
        'paramName': paramName,
        'options': options,
        'enabled': enabled,
        'isReasoningToggle': isReasoningToggle,
        'isEffortParam': isEffortParam,
        if (onValue != null) 'onValue': onValue,
        if (offValue != null) 'offValue': offValue,
        'type': type,
      };

  factory ReasoningParam.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('defaultValue') && !map.containsKey('options')) {
      return ReasoningParam(
        paramName: map['paramName'] as String? ?? '',
        options: [],
        hasExplicitEffortFlag: map.containsKey('isEffortParam'),
      );
    }
    return ReasoningParam(
      paramName: map['paramName'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      isReasoningToggle: map['isReasoningToggle'] as bool? ?? false,
      isEffortParam: map['isEffortParam'] as bool? ?? false,
      hasExplicitEffortFlag: map.containsKey('isEffortParam'),
      onValue: map['onValue'] as String?,
      offValue: map['offValue'] as String?,
      options:
          (map['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      type: map['type'] as String? ?? 'string',
    );
  }

  ReasoningParam copy() => ReasoningParam(
        paramName: paramName,
        enabled: enabled,
        isReasoningToggle: isReasoningToggle,
        isEffortParam: isEffortParam,
        hasExplicitEffortFlag: hasExplicitEffortFlag,
        onValue: onValue,
        offValue: offValue,
        options: List<String>.from(options),
        type: type,
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

/// Finds the reasoning effort param (推理力度) in [params].
///
/// Resolution order:
/// 1. The param explicitly marked `isEffortParam == true`.
/// 2. Legacy data only (no param carries an explicit `isEffortParam` key,
///    i.e. data saved before the flag existed): the first non-toggle param
///    with a non-empty name and non-empty options — the pre-flag "effort =
///    first non-toggle" semantics. Modern data that deliberately has no
///    effort param is never misclassified (returns null instead).
ReasoningParam? findEffortParam(List<ReasoningParam> params) {
  final explicit = params.cast<ReasoningParam?>().firstWhere(
        (p) => p?.isEffortParam ?? false,
        orElse: () => null,
      );
  if (explicit != null) return explicit;
  final anyExplicitFlag = params.any((p) => p.hasExplicitEffortFlag);
  if (anyExplicitFlag) return null;
  return params.cast<ReasoningParam?>().firstWhere(
        (p) =>
            p != null &&
            !p.isReasoningToggle &&
            p.paramName.trim().isNotEmpty &&
            p.options.isNotEmpty,
        orElse: () => null,
      );
}

/// Ensures the effort param of [params] matches the effort toggle state in
/// [values]:
/// - toggle ON: writes the first option when none was selected yet;
/// - toggle OFF: removes any leftover effort value (so the request stops
///   sending it and the chip shows "推理").
/// Returns [values] unchanged when nothing needs writing (so callers can
/// skip the provider update).
Map<String, String> ensureEffortValue(
  List<ReasoningParam> params,
  Map<String, String> values, {
  required bool effortEnabled,
}) {
  final effort = findEffortParam(params);
  if (effort == null) return values;
  if (effortEnabled) {
    if (effort.enabled &&
        effort.options.isNotEmpty &&
        (values[effort.paramName]?.isNotEmpty ?? false) != true) {
      return {...values, effort.paramName: effort.options.first};
    }
    return values;
  }
  if (values.containsKey(effort.paramName)) {
    return Map<String, String>.from(values)..remove(effort.paramName);
  }
  return values;
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

  /// 端点类型覆盖（'openai' | 'anthropic'）。
  /// null 表示继承所在供应商的端点类型（默认）。
  /// v3 原位演进：旧数据缺省 null = 继承，无需迁移步骤。
  String? endpointType;

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
    this.endpointType,
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
        if (endpointType != null) 'endpointType': endpointType,
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
        endpointType: map['endpointType'] as String?,
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
        endpointType: endpointType,
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
  Map<String, dynamic> typeConfig;
  List<CustomParam> customParams;
  List<ReasoningParam> reasoningParams;

  /// 端点类型（'openai' | 'anthropic'），该供应商下所有对话统一走此协议。
  /// 旧配置缺省 'openai'（v3 原位演进，无需迁移步骤）。
  String endpointType;

  ProviderConfigItem({
    this.providerName = '',
    this.host = '',
    this.key = '',
    List<ModelConfig>? models,
    this.typeConfig = const {},
    List<CustomParam>? customParams,
    List<ReasoningParam>? reasoningParams,
    this.endpointType = 'openai',
  })  : models = models ?? [],
        customParams = customParams ?? [],
        reasoningParams = reasoningParams ?? [];

  Map<String, dynamic> toMap() => {
        'providerName': providerName,
        'host': host,
        'key': key,
        'models': models.map((m) => m.toMap()).toList(),
        'typeConfig': typeConfig,
        'customParams': customParams.map((p) => p.toMap()).toList(),
        'reasoningParams': reasoningParams.map((p) => p.toMap()).toList(),
        'endpointType': endpointType,
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
        typeConfig: Map<String, dynamic>.from(map['typeConfig'] as Map? ?? {}),
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
        endpointType: map['endpointType'] as String? ?? 'openai',
      );

  ProviderConfigItem copy() => ProviderConfigItem(
        providerName: providerName,
        host: host,
        key: key,
        models: models.map((m) => m.copy()).toList(),
        typeConfig: Map<String, dynamic>.from(typeConfig),
        customParams: customParams.map((p) => p.copy()).toList(),
        reasoningParams: reasoningParams.map((p) => p.copy()).toList(),
        endpointType: endpointType,
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
