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
  final bool streamOutput;
  final bool enableWebSearch;
  final int maxToolCalls;
  final bool enableMaxToolCalls;
  final double frequencyPenalty;
  final bool enableFrequencyPenalty;
  final double presencePenalty;
  final bool enablePresencePenalty;
  final int? seed;
  final bool enableSeed;
  final List<CustomParameter> customParameters;

  AssistantSettings({
    this.temperature = 1.0,
    this.enableTemperature = false,
    this.topP = 1.0,
    this.enableTopP = false,
    this.maxTokens = 4096,
    this.enableMaxTokens = false,
    this.streamOutput = true,
    this.enableWebSearch = false,
    this.maxToolCalls = 20,
    this.enableMaxToolCalls = true,
    this.frequencyPenalty = 0.0,
    this.enableFrequencyPenalty = false,
    this.presencePenalty = 0.0,
    this.enablePresencePenalty = false,
    this.seed,
    this.enableSeed = false,
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
        'streamOutput': streamOutput,
        'enableWebSearch': enableWebSearch,
        'maxToolCalls': maxToolCalls,
        'enableMaxToolCalls': enableMaxToolCalls,
        'frequencyPenalty': frequencyPenalty,
        'enableFrequencyPenalty': enableFrequencyPenalty,
        'presencePenalty': presencePenalty,
        'enablePresencePenalty': enablePresencePenalty,
        if (seed != null) 'seed': seed,
        'enableSeed': enableSeed,
        'customParameters': customParameters.map((p) => p.toMap()).toList(),
      };

  factory AssistantSettings.fromMap(Map<String, dynamic> map) =>
      AssistantSettings(
        temperature: (map['temperature'] as num?)?.toDouble() ?? 1.0,
        enableTemperature: (map['enableTemperature'] as bool?) ?? false,
        topP: (map['topP'] as num?)?.toDouble() ?? 1.0,
        enableTopP: (map['enableTopP'] as bool?) ?? false,
        maxTokens: (map['maxTokens'] as int?) ?? 4096,
        enableMaxTokens: (map['enableMaxTokens'] as bool?) ?? false,
        streamOutput: (map['streamOutput'] as bool?) ?? true,
        enableWebSearch: (map['enableWebSearch'] as bool?) ?? false,
        maxToolCalls: (map['maxToolCalls'] as int?) ?? 20,
        enableMaxToolCalls: (map['enableMaxToolCalls'] as bool?) ?? true,
        frequencyPenalty: (map['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
        enableFrequencyPenalty:
            (map['enableFrequencyPenalty'] as bool?) ?? false,
        presencePenalty: (map['presencePenalty'] as num?)?.toDouble() ?? 0.0,
        enablePresencePenalty: (map['enablePresencePenalty'] as bool?) ?? false,
        seed: map['seed'] as int?,
        enableSeed: (map['enableSeed'] as bool?) ?? false,
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
    bool? streamOutput,
    bool? enableWebSearch,
    int? maxToolCalls,
    bool? enableMaxToolCalls,
    double? frequencyPenalty,
    bool? enableFrequencyPenalty,
    double? presencePenalty,
    bool? enablePresencePenalty,
    int? seed,
    bool? enableSeed,
    List<CustomParameter>? customParameters,
  }) =>
      AssistantSettings(
        temperature: temperature ?? this.temperature,
        enableTemperature: enableTemperature ?? this.enableTemperature,
        topP: topP ?? this.topP,
        enableTopP: enableTopP ?? this.enableTopP,
        maxTokens: maxTokens ?? this.maxTokens,
        enableMaxTokens: enableMaxTokens ?? this.enableMaxTokens,
        streamOutput: streamOutput ?? this.streamOutput,
        enableWebSearch: enableWebSearch ?? this.enableWebSearch,
        maxToolCalls: maxToolCalls ?? this.maxToolCalls,
        enableMaxToolCalls: enableMaxToolCalls ?? this.enableMaxToolCalls,
        frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
        enableFrequencyPenalty:
            enableFrequencyPenalty ?? this.enableFrequencyPenalty,
        presencePenalty: presencePenalty ?? this.presencePenalty,
        enablePresencePenalty:
            enablePresencePenalty ?? this.enablePresencePenalty,
        seed: seed ?? this.seed,
        enableSeed: enableSeed ?? this.enableSeed,
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
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Creates an Assistant from a map, e.g. from stored JSON.
  ///
  /// Handles legacy data that may include old `avatarType`/`avatarUrl` fields —
  /// those are ignored since emoji is the only avatar mode now.
  factory Assistant.fromMap(Map<String, dynamic> map) {
    final settingsMap = map['settings'] as Map<String, dynamic>?;
    return Assistant(
      id: map['id'] as String?,
      name: (map['name'] as String?) ?? '',
      prompt: (map['prompt'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '🤖',
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
        description: description ?? this.description,
        settings: settings ?? this.settings,
        modelId: modelId ?? this.modelId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() => 'Assistant(id: $id, name: $name)';
}
