import 'package:uuid/uuid.dart';

// ============================================================================
// Custom parameter — user-defined model parameters
// ============================================================================

class CustomParameter {
  final String name;
  final String type; // 'string' | 'number' | 'boolean' | 'json'
  final dynamic value;

  CustomParameter({
    required this.name,
    required this.type,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'value': value,
      };

  factory CustomParameter.fromMap(Map<String, dynamic> map) => CustomParameter(
        name: (map['name'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'string',
        value: map['value'],
      );
}

// ============================================================================
// Assistant settings — inference parameters + source toggles
// ============================================================================

class AssistantSettings {
  final double temperature;
  final bool enableTemperature;
  final double topP;
  final bool enableTopP;
  final int maxTokens;
  final bool enableMaxTokens;
  final int topK;
  final bool enableTopK;
  final double frequencyPenalty;
  final bool enableFrequencyPenalty;
  final double presencePenalty;
  final bool enablePresencePenalty;
  final bool streamOutput;
  final String reasoningEffort;
  final bool enableWebSearch;
  final int maxToolCalls;
  final bool enableMaxToolCalls;
  final bool overrideModelSettings;
  final List<CustomParameter> customParameters;

  AssistantSettings({
    this.temperature = 1.0,
    this.enableTemperature = false,
    this.topP = 1.0,
    this.enableTopP = false,
    this.maxTokens = 4096,
    this.enableMaxTokens = false,
    this.topK = 0,
    this.enableTopK = false,
    this.frequencyPenalty = 0.0,
    this.enableFrequencyPenalty = false,
    this.presencePenalty = 0.0,
    this.enablePresencePenalty = false,
    this.streamOutput = true,
    this.reasoningEffort = 'default',
    this.enableWebSearch = false,
    this.maxToolCalls = 20,
    this.enableMaxToolCalls = true,
    this.overrideModelSettings = false,
    this.customParameters = const [],
  });

  factory AssistantSettings.defaults() => AssistantSettings();

  Map<String, dynamic> toMap() => {
        'temperature': temperature,
        'enableTemperature': enableTemperature,
        'topP': topP,
        'enableTopP': enableTopP,
        'maxTokens': maxTokens,
        'enableMaxTokens': enableMaxTokens,
        if (topK != 0 || enableTopK) 'topK': topK,
        if (enableTopK) 'enableTopK': enableTopK,
        if (frequencyPenalty != 0.0 || enableFrequencyPenalty)
          'frequencyPenalty': frequencyPenalty,
        if (enableFrequencyPenalty) 'enableFrequencyPenalty': enableFrequencyPenalty,
        if (presencePenalty != 0.0 || enablePresencePenalty)
          'presencePenalty': presencePenalty,
        if (enablePresencePenalty) 'enablePresencePenalty': enablePresencePenalty,
        'streamOutput': streamOutput,
        'reasoningEffort': reasoningEffort,
        'enableWebSearch': enableWebSearch,
        'maxToolCalls': maxToolCalls,
        'enableMaxToolCalls': enableMaxToolCalls,
        if (overrideModelSettings) 'overrideModelSettings': overrideModelSettings,
        'customParameters':
            customParameters.map((p) => p.toMap()).toList(),
      };

  factory AssistantSettings.fromMap(Map<String, dynamic> map) =>
      AssistantSettings(
        temperature: (map['temperature'] as num?)?.toDouble() ?? 1.0,
        enableTemperature: (map['enableTemperature'] as bool?) ?? false,
        topP: (map['topP'] as num?)?.toDouble() ?? 1.0,
        enableTopP: (map['enableTopP'] as bool?) ?? false,
        maxTokens: (map['maxTokens'] as int?) ?? 4096,
        enableMaxTokens: (map['enableMaxTokens'] as bool?) ?? false,
        topK: (map['topK'] as int?) ?? 0,
        enableTopK: (map['enableTopK'] as bool?) ?? false,
        frequencyPenalty: (map['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        enableFrequencyPenalty:
            (map['enableFrequencyPenalty'] as bool?) ?? false,
        presencePenalty: (map['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        enablePresencePenalty:
            (map['enablePresencePenalty'] as bool?) ?? false,
        streamOutput: (map['streamOutput'] as bool?) ?? true,
        reasoningEffort: (map['reasoningEffort'] as String?) ?? 'default',
        enableWebSearch: (map['enableWebSearch'] as bool?) ?? false,
        maxToolCalls: (map['maxToolCalls'] as int?) ?? 20,
        enableMaxToolCalls: (map['enableMaxToolCalls'] as bool?) ?? true,
        overrideModelSettings:
            (map['overrideModelSettings'] as bool?) ?? false,
        customParameters: (map['customParameters'] as List?)
                ?.map((e) =>
                    CustomParameter.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );

  AssistantSettings copyWith({
    double? temperature,
    bool? enableTemperature,
    double? topP,
    bool? enableTopP,
    int? maxTokens,
    bool? enableMaxTokens,
    int? topK,
    bool? enableTopK,
    double? frequencyPenalty,
    bool? enableFrequencyPenalty,
    double? presencePenalty,
    bool? enablePresencePenalty,
    bool? streamOutput,
    String? reasoningEffort,
    bool? enableWebSearch,
    int? maxToolCalls,
    bool? enableMaxToolCalls,
    bool? overrideModelSettings,
    List<CustomParameter>? customParameters,
  }) =>
      AssistantSettings(
        temperature: temperature ?? this.temperature,
        enableTemperature: enableTemperature ?? this.enableTemperature,
        topP: topP ?? this.topP,
        enableTopP: enableTopP ?? this.enableTopP,
        maxTokens: maxTokens ?? this.maxTokens,
        enableMaxTokens: enableMaxTokens ?? this.enableMaxTokens,
        topK: topK ?? this.topK,
        enableTopK: enableTopK ?? this.enableTopK,
        frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
        enableFrequencyPenalty:
            enableFrequencyPenalty ?? this.enableFrequencyPenalty,
        presencePenalty: presencePenalty ?? this.presencePenalty,
        enablePresencePenalty:
            enablePresencePenalty ?? this.enablePresencePenalty,
        streamOutput: streamOutput ?? this.streamOutput,
        reasoningEffort: reasoningEffort ?? this.reasoningEffort,
        enableWebSearch: enableWebSearch ?? this.enableWebSearch,
        maxToolCalls: maxToolCalls ?? this.maxToolCalls,
        enableMaxToolCalls: enableMaxToolCalls ?? this.enableMaxToolCalls,
        overrideModelSettings:
            overrideModelSettings ?? this.overrideModelSettings,
        customParameters: customParameters ?? this.customParameters,
      );
}

// ============================================================================
// Assistant entity
// ============================================================================

class Assistant {
  final String id;
  final String name;
  final String prompt;
  final String emoji;
  final String? avatarPath;
  final String description;
  final AssistantSettings settings;
  final String? modelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assistant({
    String? id,
    required this.name,
    required this.prompt,
    this.emoji = '🤖',
    this.avatarPath,
    this.description = '',
    AssistantSettings? settings,
    this.modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        settings = settings ?? AssistantSettings.defaults(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'prompt': prompt,
        'emoji': emoji,
        'description': description,
        'settings': settings.toMap(),
        if (modelId != null) 'modelId': modelId,
        if (avatarPath != null) 'avatarPath': avatarPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Assistant.fromMap(Map<String, dynamic> map) {
    final settingsMap = map['settings'] as Map<String, dynamic>?;
    return Assistant(
      id: map['id'] as String?,
      name: (map['name'] as String?) ?? '',
      prompt: (map['prompt'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '🤖',
      avatarPath: map['avatarPath'] as String?,
      description: (map['description'] as String?) ?? '',
      settings: settingsMap != null
          ? AssistantSettings.fromMap(settingsMap)
          : AssistantSettings.defaults(),
      modelId: map['modelId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  Assistant copyWith({
    String? id,
    String? name,
    String? prompt,
    String? emoji,
    String? avatarPath,
    String? description,
    AssistantSettings? settings,
    String? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Assistant(
        id: id ?? this.id,
        name: name ?? this.name,
        prompt: prompt ?? this.prompt,
        emoji: emoji ?? this.emoji,
        avatarPath: avatarPath ?? this.avatarPath,
        description: description ?? this.description,
        settings: settings ?? this.settings,
        modelId: modelId ?? this.modelId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() => 'Assistant(id: $id, name: $name)';
}
