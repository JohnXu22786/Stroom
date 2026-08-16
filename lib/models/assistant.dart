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

  /// 工具结果发送给模型前的渲染截断上限（**字符数**，非 token/字节）。
  /// 默认 5000 字符；关闭开关（[enableMaxToolOutputChars] = false）时
  /// 完整发送存储的工具结果（存储仍有 50KB 上限）。
  final int maxToolOutputChars;
  final bool enableMaxToolOutputChars;
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
    this.maxToolOutputChars = 5000,
    this.enableMaxToolOutputChars = true,
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
        'maxToolOutputChars': maxToolOutputChars,
        'enableMaxToolOutputChars': enableMaxToolOutputChars,
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
        // 旧数据缺失时默认开启、5000 字符（与构造默认一致）。
        maxToolOutputChars: (map['maxToolOutputChars'] as int?) ?? 5000,
        enableMaxToolOutputChars:
            (map['enableMaxToolOutputChars'] as bool?) ?? true,
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
    int? maxToolOutputChars,
    bool? enableMaxToolOutputChars,
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
        maxToolOutputChars:
            maxToolOutputChars ?? this.maxToolOutputChars,
        enableMaxToolOutputChars: enableMaxToolOutputChars ??
            this.enableMaxToolOutputChars,
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

  /// 该助手新建话题（对话）时使用的默认模型显示名
  /// （"modelName | providerName" 格式，与 [Conversation.lastUsedModelName]
  /// 同一命名空间）。为 null 时暂不设置默认模型：新话题回退到对话页
  /// 模型列表的第一个（显示顺序）。
  /// 用户在某条对话内切换模型后，以对话自身的记录为准，互不影响。
  final String? defaultModelName;

  /// 默认模型的 API 模型 ID（绝对身份，配合 [defaultProviderName]）。
  ///
  /// 显示名可能因模型/供应商重命名而过期，模型 ID + 供应商名在重命名后
  /// 仍能解析回同一模型。旧数据（仅显示名）为 null，回退到显示名匹配。
  final String? defaultModelId;

  /// 默认模型所属供应商名称（绝对身份的一部分）。
  final String? defaultProviderName;

  /// 该助手新建话题（对话）时默认启用的工具名集合。
  /// 未添加进此集合的工具在新话题中保持关闭。
  /// 对话内用户手动开关工具后，以对话自身的记录为准。
  ///
  /// null 表示"从未配置过默认工具"——新话题保持原有行为
  /// （自动启用全部可用工具）；非 null（含空集合）表示已配置，
  /// 新话题严格使用该集合（未添加的工具保持关闭）。
  /// 该三态区分需要跨序列化存活，因此 toMap 在非 null 时总是写出
  /// 该字段（包括空集合）。
  final Set<String>? defaultToolNames;

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
    this.defaultModelName,
    this.defaultModelId,
    this.defaultProviderName,
    this.defaultToolNames,
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
        if (defaultModelName != null && defaultModelName!.isNotEmpty)
          'defaultModelName': defaultModelName,
        if (defaultModelId != null && defaultModelId!.isNotEmpty)
          'defaultModelId': defaultModelId,
        if (defaultProviderName != null && defaultProviderName!.isNotEmpty)
          'defaultProviderName': defaultProviderName,
        // 非 null 时总是写出（含空集合）：区分"配置过但全关"与"从未配置"。
        if (defaultToolNames != null)
          'defaultToolNames': defaultToolNames!.toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Creates an Assistant from a map, e.g. from stored JSON.
  ///
  /// Handles legacy data that may include old `avatarType`/`avatarUrl` fields —
  /// those are ignored since emoji is the only avatar mode now.
  factory Assistant.fromMap(Map<String, dynamic> map) {
    final settingsMap = map['settings'] as Map<String, dynamic>?;
    final defaultModelNameRaw = map['defaultModelName'];
    final defaultToolsRaw = map['defaultToolNames'];
    // 字段存在（含空列表）→ 已配置；缺失 → 从未配置（null）。
    // 迁移：todowrite / todoread 已合并为单一 todowrite（读写一体），
    // 旧数据里显式配置了 todoread 的助手，把该默认偏好迁移为新工具名，
    // 避免合并后仅开启 todoread 的助手默认配置里 todo 工具静默失效。
    Set<String>? defaultToolNames;
    if (defaultToolsRaw != null) {
      defaultToolNames = defaultToolsRaw is List
          ? defaultToolsRaw.map((e) => e.toString()).toSet()
          : <String>{};
      if (defaultToolNames.remove('todoread')) {
        defaultToolNames.add('todowrite');
      }
    }
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
      defaultModelName:
          defaultModelNameRaw is String && defaultModelNameRaw.isNotEmpty
              ? defaultModelNameRaw
              : null,
      defaultModelId: map['defaultModelId'] as String?,
      defaultProviderName: map['defaultProviderName'] as String?,
      defaultToolNames: defaultToolNames,
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
    String? defaultModelName,
    String? defaultModelId,
    String? defaultProviderName,
    Set<String>? defaultToolNames,
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
        defaultModelName: defaultModelName ?? this.defaultModelName,
        defaultModelId: defaultModelId ?? this.defaultModelId,
        defaultProviderName: defaultProviderName ?? this.defaultProviderName,
        defaultToolNames: defaultToolNames ?? this.defaultToolNames,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() => 'Assistant(id: $id, name: $name)';
}
