import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

// ============================================================================
// 自定义参数
// ============================================================================

/// 参数类型枚举
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

  /// 在 JSON 模板中是否需要用引号包裹
  bool get needsQuotes => this == string;

  /// 默认值示例
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

class CustomParam {
  String paramName;
  String defaultValue;
  String type; // 'string', 'number', 'boolean'

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

/// 裁切方向
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

/// 裁切预设（全局共享）
class TrimPreset {
  String id;
  String name; // 切割方式名称
  double durationSeconds; // 切割时长（秒）
  String direction; // 'head' 或 'tail'

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
  String name; // 音色名称，如 "标准女生"
  String id; // 音色ID，如 "female"

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
// 推理参数（用户自定义参数名和选项值）
// ============================================================================

/// 推理参数，由用户在模型设置中自定义参数名和可选的选项值列表。
/// 在对话页面的推理面板中，每个参数显示为带选项 chips 的标签行。
/// 
/// 第一个参数为"推理开关"（isReasoningToggle=true），由用户定义参数名、
/// 开启时的值（onValue）和关闭时的值（offValue）。该参数不显示在推理面板中，
/// 而是由聊天页面的推理总开关直接控制。
///
/// 后续参数（isReasoningToggle=false）为附加推理参数，包含参数名和可选项列表，
/// 在推理面板中供用户选择具体值。
class ReasoningParam {
  /// 参数名，支持点号嵌套（如 thinking.type → {"thinking": {"type": "enabled"}}）
  String paramName;

  /// 选项值列表，按用户添加的顺序显示在推理面板中。
  /// 例如 ['low', 'medium', 'high'] 或 ['true', 'false'] 或 ['max']
  List<String> options;

  /// 推理参数的独立开关（仅对非推理开关的附加参数有效）。
  bool enabled;

  /// 是否为此模型的推理开关（第一个默认参数）。
  /// 推理开关不会显示在推理面板中，由聊天页面的总开关控制。
  bool isReasoningToggle;

  /// 推理开关开启时发送的值（如 'enabled'、'true'）。
  /// 仅对 isReasoningToggle=true 有效。
  String? onValue;

  /// 推理开关关闭时发送的值（如 'disabled'、'false'）。
  /// 仅对 isReasoningToggle=true 有效。
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
    // Handle old format (CustomParam with defaultValue/type)
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

  /// 验证此参数是否有效。
  /// 所有参数必须：paramName 不能为空。
  /// 推理开关必须：onValue 和 offValue 不能为空。
  /// 非推理开关的附加参数：options 中的每个值不能为空。
  String? get validationError {
    if (paramName.trim().isEmpty) return '参数名不能为空';
    if (isReasoningToggle) {
      if (onValue == null || onValue!.trim().isEmpty) {
        return '推理开关开启值不能为空';
      }
      if (offValue == null || offValue!.trim().isEmpty) {
        return '推理开关关闭值不能为空';
      }
    } else {
      for (int j = 0; j < options.length; j++) {
        if (options[j].trim().isEmpty) {
          return '选项值不能为空';
        }
      }
    }
    return null;
  }
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
  List<ReasoningParam> reasoningParams; // 推理参数（仅推理开启时发送）
  int maxWordsPerRequest; // 单次最长音频字数
  bool supportStream; // 是否支持流式输出
  bool supportInstruction; // 是否支持 instruction 参数
  Map<String, dynamic> typeConfig; // 类型特有参数
  String? selectedTrimPresetId; // 当前选中的裁切预设ID

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
  String type; // 'tts' | 'llm'
  String name; // 显示名称，如 "TTS供应商"
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
    // 新格式
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

// ============================================================================
// 供应商类型注册表 — 每种类型可注册默认值，新增类型只需注册一次
// ============================================================================

/// 模型配置页面的样式
enum ModelConfigStyle {
  /// TTS 样式：音色、音量、语速、裁切、流式输出、instruction 等
  tts,
  /// LLM 样式：模型ID、上下文长度、自定义参数
  llm,
  /// 简洁样式：模型ID、自定义参数（无上下文长度要求），用于 OCR、ASR
  simple,
}

class ProviderTypeDefinition {
  final String type;
  final String? defaultHost;
  final String? hostHint;
  final List<ModelConfig> defaultModels;
  final ModelConfigStyle modelConfigStyle;

  bool get useLlmModelConfig => modelConfigStyle == ModelConfigStyle.llm;

  const ProviderTypeDefinition({
    required this.type,
    this.defaultHost,
    this.hostHint,
    this.defaultModels = const [],
    this.modelConfigStyle = ModelConfigStyle.tts,
  });
}

class ProviderTypeRegistry {
  static final Map<String, ProviderTypeDefinition> _registry = {};

  static void register(ProviderTypeDefinition def) {
    _registry[def.type] = def;
  }

  static ProviderTypeDefinition? get(String type) => _registry[type];

  static bool isRegistered(String type) => _registry.containsKey(type);
}

void registerBuiltinProviderTypes() {
  ProviderTypeRegistry.register(const ProviderTypeDefinition(
    type: 'llm',
    hostHint: '例如: https://api.openai.com/v1/chat/completions',
    modelConfigStyle: ModelConfigStyle.llm,
  ));
  ProviderTypeRegistry.register(const ProviderTypeDefinition(
    type: 'tts',
    hostHint: '例如: https://api.openai.com/v1/audio/speech',
    modelConfigStyle: ModelConfigStyle.tts,
  ));
  ProviderTypeRegistry.register(const ProviderTypeDefinition(
    type: 'ocr',
    hostHint: '例如: https://api.openai.com/v1/chat/completions',
    modelConfigStyle: ModelConfigStyle.simple,
  ));
  ProviderTypeRegistry.register(const ProviderTypeDefinition(
    type: 'asr',
    hostHint: '例如: https://api.openai.com/v1/audio/transcriptions',
    modelConfigStyle: ModelConfigStyle.simple,
  ));
  ProviderTypeRegistry.register(const ProviderTypeDefinition(
    type: 'mcp',
    hostHint: '例如: http://localhost:3001/sse',
  ));
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

      // 第1步：迁移旧版 chat_configs → provider_entries
      await _migrateOldChatConfigs(prefs);

      // 第2步：迁移旧版 CustomParam 缺少 type 字段的问题
      await _migrateOldCustomParams(prefs);

      // 第3步：正常加载 provider_entries
      final json = prefs.getString('provider_entries');
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        final entries = list.map((m) => ProviderEntry.fromMap(m)).toList();

        // 第4步：确保 OCR 条目存在（已有用户升级时自动迁移）
        final hasOcr = entries.any((e) => e.type == 'ocr');
        if (!hasOcr) {
          entries.add(ProviderEntry(
            id: 'builtin_ocr',
            type: 'ocr',
            name: 'OCR供应商',
          ));
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        // 第5步：确保 ASR（语音识别）条目存在（已有用户升级时自动迁移）
        final hasAsr = entries.any((e) => e.type == 'asr');
        if (!hasAsr) {
          entries.add(ProviderEntry(
            id: 'builtin_asr',
            type: 'asr',
            name: '语音识别供应商',
          ));
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        // 第6步：确保 MCP 条目存在（已有用户升级时自动迁移）
        final hasMcp = entries.any((e) => e.type == 'mcp');
        if (!hasMcp) {
          entries.add(ProviderEntry(
            id: 'builtin_mcp',
            type: 'mcp',
            name: 'MCP供应商',
          ));
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        state = ProviderEntriesState(entries: entries);
        return;
      }
    } catch (e) {
      debugPrint('Failed to load provider entries: $e');
    }

    // 默认预置
    state = ProviderEntriesState(entries: [
      ProviderEntry(
        id: 'builtin_tts',
        type: 'tts',
        name: 'TTS供应商',
      ),
      ProviderEntry(
        id: 'builtin_llm',
        type: 'llm',
        name: 'LLM供应商',
      ),
      ProviderEntry(
        id: 'builtin_ocr',
        type: 'ocr',
        name: 'OCR供应商',
      ),
      ProviderEntry(
        id: 'builtin_asr',
        type: 'asr',
        name: '语音识别供应商',
      ),
      ProviderEntry(
        id: 'builtin_mcp',
        type: 'mcp',
        name: 'MCP供应商',
      ),
    ]);
  }

  /// 迁移旧版 chat_configs（被重构删除的 ChatProviderConfigItem 格式）到 provider_entries
  Future<void> _migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      final oldList =
          (jsonDecode(oldJson) as List).cast<Map<String, dynamic>>();
      if (oldList.isEmpty) return;

      final migratedConfigs = <ProviderConfigItem>[];
      for (final oldItem in oldList) {
        final oldModels = (oldItem['models'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        final models = oldModels.map((m) {
          final typeConfig = <String, dynamic>{};
          final maxTokens = m['maxTokens'] ?? m['context'];
          if (maxTokens != null) typeConfig['context'] = maxTokens;
          final temperature = m['temperature'];
          if (temperature != null) typeConfig['temperature'] = temperature;

          return ModelConfig(
            name: m['modelId'] as String? ?? '',
            modelId: m['modelId'] as String? ?? '',
            supportStream: m['supportStream'] as bool? ?? true,
            typeConfig: typeConfig,
          );
        }).toList();

        migratedConfigs.add(ProviderConfigItem(
          providerName: oldItem['providerName'] as String? ?? '',
          host: oldItem['host'] as String? ?? '',
          key: oldItem['key'] as String? ?? '',
          models: models,
        ));
      }

      if (migratedConfigs.isEmpty) return;

      // 读取或初始化当前 provider_entries
      String? existingJson;
      try {
        existingJson = prefs.getString('provider_entries');
      } catch (_) {}

      List<Map<String, dynamic>> existingEntries = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        existingEntries =
            (jsonDecode(existingJson) as List).cast<Map<String, dynamic>>();
      }

      // 如果已有 llm 类型条目则不覆盖
      final hasLlmEntry =
          existingEntries.any((e) => e['type'] == 'llm' && e['id'] != 'builtin_llm');
      if (!hasLlmEntry) {
        existingEntries.add({
          'id': 'migrated_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': migratedConfigs.map((c) => c.toMap()).toList(),
        });

        await prefs.setString('provider_entries', jsonEncode(existingEntries));
      }

      // 删除旧数据，防止重复迁移
      await prefs.remove('chat_configs');
      await prefs.remove('chat_selected_config_id');
      debugPrint(
          'Migrated ${oldList.length} old chat config(s) to provider_entries');
    } catch (e) {
      debugPrint('Failed to migrate old chat configs: $e');
    }
  }

  Future<void> _migrateOldCustomParams(SharedPreferences prefs) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      bool changed = false;

      for (final entry in list) {
        final configs = entry['configs'] as List?;
        if (configs == null) continue;
        for (final config in configs) {
          final configMap = config as Map<String, dynamic>;
          final models = configMap['models'] as List?;
          if (models == null) continue;
          for (final model in models) {
            final modelMap = model as Map<String, dynamic>;
            final customParams = modelMap['customParams'] as List?;
            if (customParams == null) continue;
            for (int i = 0; i < customParams.length; i++) {
              final param = customParams[i] as Map<String, dynamic>;
              if (param['type'] == null) {
                param['type'] = 'string';
                changed = true;
              }
            }
          }
        }
      }

      if (changed) {
        await prefs.setString('provider_entries', jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Failed to migrate custom param types: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.entries.map((e) => e.toMap()).toList());
      await prefs.setString('provider_entries', json);
    } catch (e) {
      debugPrint('Failed to persist provider entries: $e');
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
