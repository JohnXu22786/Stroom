import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_shared.dart';

part 'llm_model_config_page_custom_params.dart';
part 'llm_model_config_page_reasoning.dart';
part 'llm_model_config_page_reasoning_builders.dart';
part 'llm_model_config_page_save.dart';
part 'llm_model_config_page_sections.dart';

/// LLM 模型配置编辑页面
/// 包含基本设置和 LLM 专有参数（温度、Top P 等）
class LlmModelConfigPage extends StatefulWidget {
  final ModelConfig? model; // null = 新建, non-null = 编辑

  /// 所属供应商配置。供应商已配置的推理参数会实时合并显示到本页
  /// （继承视图），模型修改后参数才变为模型独立配置。
  final ProviderConfigItem? provider;

  const LlmModelConfigPage({super.key, this.model, this.provider});

  @override
  State<LlmModelConfigPage> createState() => _LlmModelConfigPageState();
}

class _LlmModelConfigPageState extends State<LlmModelConfigPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelIdController;
  late final TextEditingController _contextController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _seedController;
  late List<CustomParam> _customParams;
  late List<ReasoningParam> _reasoningParams;

  // ===================================================================
  // 推理力度参数「勾选块」状态（仅内存，不序列化）
  //
  // 模型页力度参数以块（OptionChip 风格）展示：块 = 一个可选值，
  // 点击高亮选中、再点取消（多选）；块来自供应商提供的值 + 模型
  // 自己添加的值。勾选结果按块顺序写入模型的 options。
  // ===================================================================

  /// 所有力度块的顺序（供应商值在前 + 模型独有值在后），可拖拽排序。
  late List<String> _effortBlockValues;

  /// 当前勾选（高亮）的值集合。
  late Set<String> _effortSelectedValues;

  /// 打开页面时供应商提供的力度值集合——来源判定：供应商的块不能
  /// 删除（只能取消勾选），模型自己添加的块带删除按钮。
  late Set<String> _providerEffortValues;

  /// 打开页面时各推理参数工作副本的初始快照（reset 还原用，按实例
  /// 身份索引；工作副本实例在会话内不变）。
  late final Map<ReasoningParam, ReasoningParam> _initialParamSnapshots;

  /// 打开页面时力度块状态的初始快照（reset 还原用）。
  late List<String> _initialBlockValues;
  late Set<String> _initialSelectedValues;

  // ===================================================================
  // 附加推理参数「勾选块」状态（仅内存，不序列化）
  // 与推理力度相同的胶囊块编辑样式：块 = 选项值，点击勾选/取消
  // （默认全选），长按拖拽排序；供应商来源的块不可删除。
  // ===================================================================

  /// 每个附加参数（string/number 类型）的块顺序。
  final Map<ReasoningParam, List<String>> _additionalBlockValues = {};

  /// 每个附加参数的勾选集合。
  final Map<ReasoningParam, Set<String>> _additionalSelectedValues = {};

  /// 每个附加参数在供应商侧的选项值集合（删除按钮判定）。
  final Map<ReasoningParam, Set<String>> _providerAdditionalValues = {};

  /// 自定义参数（CustomParam）选项的勾选集合（照搬推理力度块交互，
  /// 默认全选；保存时 options = 勾选的选项）。
  final Map<CustomParam, Set<String>> _customParamSelectedValues = {};

  /// reset 版本号：每次还原参数时 +1，用于强制重建推理区输入框
  /// （TextFormField 的 internal state 不会跟随 initialValue 更新，
  /// 必须重建才能显示还原后的值）。
  int _reasoningResetVersion = 0;

  final Map<int, String?> _jsonErrors = {};

  // Slider values
  double _temperature = 0.7;
  double _topP = 1.0;
  double _frequencyPenalty = 0.0;
  double _presencePenalty = 0.0;

  // Toggle flags (like AssistantSettings)
  bool _enableTemperature = false;
  bool _enableTopP = false;
  bool _enableFrequencyPenalty = false;
  bool _enablePresencePenalty = false;
  bool _enableMaxTokens = false;
  bool _enableSeed = false;

  // 端点类型覆盖（默认关 = 继承供应商的端点类型）
  bool _overrideEndpointType = false;
  String _endpointType = 'openai';

  bool _isSaving = false;

  bool get _isEditing => widget.model != null;

  /// Whether the user has made unsaved changes.
  bool get _hasUnsavedChanges {
    final m = widget.model;
    if (m == null) {
      // New model: check if any field is non-empty or any param added
      if (_nameController.text.isNotEmpty) return true;
      if (_modelIdController.text.isNotEmpty) return true;
      if (_contextController.text.isNotEmpty) return true;
      if (_customParams.any((p) => p.paramName.isNotEmpty)) return true;
      // 新模型 + 供应商参数：打开即显示供应商参数不算改动，与
      // merge(provider, []) 初始态比较（默认不选 → 力度 options 为空）
      _syncEffortOptionsFromBlocks();
      _syncAdditionalOptionsFromBlocks();
      final initialReasoning = mergeReasoningParams(
        widget.provider?.reasoningParams ?? [],
        const [],
      );
      final initialEffort = initialReasoning
          .cast<ReasoningParam?>()
          .firstWhere((p) => p?.isEffortParam ?? false, orElse: () => null);
      if (initialEffort != null) {
        initialEffort.options = [];
      }
      final currentReasoning = _reasoningParams.map((p) => p.toMap()).toList();
      if (jsonEncode(initialReasoning.map((p) => p.toMap()).toList()) !=
          jsonEncode(currentReasoning)) {
        return true;
      }
      if (_enableTemperature ||
          _enableTopP ||
          _enableFrequencyPenalty ||
          _enablePresencePenalty ||
          _enableMaxTokens ||
          _enableSeed) {
        return true;
      }
      if (_maxTokensController.text.isNotEmpty) return true;
      if (_seedController.text.isNotEmpty) return true;
      if (_temperature != 0.7) return true;
      if (_topP != 1.0) return true;
      if (_frequencyPenalty != 0.0) return true;
      if (_presencePenalty != 0.0) return true;
      if (_overrideEndpointType) return true;
      return false;
    }
    // Editing: compare against original model
    if (_nameController.text != m.name) return true;
    if (_modelIdController.text != m.modelId) return true;
    // context 回退逻辑与 initState 一致（旧模型只有 maxTokens 没有
    // context 时，init 已把 maxTokens 填进输入框——这里只比较
    // context 会把"未修改"误判为"已修改"，每次返回都弹放弃确认）。
    final originalContext = (m.typeConfig['context'] as num?)?.toInt() ??
        (m.typeConfig['maxTokens'] as num?)?.toInt();
    if (_contextController.text != (originalContext?.toString() ?? '')) {
      return true;
    }
    // LLM params
    if (((m.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7) !=
        _temperature) {
      return true;
    }
    if (((m.typeConfig['topP'] as num?)?.toDouble() ?? 1.0) != _topP) {
      return true;
    }
    if (((m.typeConfig['frequencyPenalty'] as num?)?.toDouble() ?? 0.0) !=
        _frequencyPenalty) {
      return true;
    }
    if (((m.typeConfig['presencePenalty'] as num?)?.toDouble() ?? 0.0) !=
        _presencePenalty) {
      return true;
    }
    if ((m.typeConfig['enableTemperature'] as bool? ?? false) !=
        _enableTemperature) {
      return true;
    }
    if ((m.typeConfig['enableTopP'] as bool? ?? false) != _enableTopP) {
      return true;
    }
    if ((m.typeConfig['enableFrequencyPenalty'] as bool? ?? false) !=
        _enableFrequencyPenalty) {
      return true;
    }
    if ((m.typeConfig['enablePresencePenalty'] as bool? ?? false) !=
        _enablePresencePenalty) {
      return true;
    }
    if ((m.typeConfig['enableMaxTokens'] as bool? ?? false) !=
        _enableMaxTokens) {
      return true;
    }
    if ((m.typeConfig['enableSeed'] as bool? ?? false) != _enableSeed) {
      return true;
    }
    if ((m.typeConfig['maxTokens']?.toString() ?? '') !=
        _maxTokensController.text) {
      return true;
    }
    if ((m.typeConfig['seed']?.toString() ?? '') != _seedController.text) {
      return true;
    }
    // 端点类型覆盖
    final mOverride = m.endpointType;
    if ((mOverride != null) != _overrideEndpointType) return true;
    if (_overrideEndpointType && _endpointType != mOverride) return true;
    // Custom params and reasoning params (simple check via serialization)
    // 用 jsonEncode 而非 toString 比较：List/Map 的 toString 不引用
    // 字符串，空选项 [''] 会与无选项 [] 混淆。
    final originalCustom = m.customParams.map((p) => p.toMap()).toList();
    final currentCustom = _customParams.map((p) => p.toMap()).toList();
    if (jsonEncode(originalCustom) != jsonEncode(currentCustom)) return true;
    // Reasoning params: 与「打开时的初始合并视图」比较——保存会全量写入
    // 工作副本，而打开时的工作副本 = merge(provider, model) 再应用力度
    // 遮蔽与默认勾选。两者相等说明用户未做任何修改（打开即显示供应商
    // 参数不算改动）。
    // 力度勾选块先同步到工作副本，勾选/排序变化才能被检测到。
    _syncEffortOptionsFromBlocks();
    _syncAdditionalOptionsFromBlocks();
    _syncCustomParamOptionsFromBlocks();
    final initialReasoning = _applyEffortShadowing(
      mergeReasoningParams(
        widget.provider?.reasoningParams ?? [],
        m.reasoningParams,
      ),
      m.reasoningParams,
    );
    // 应用初始勾选状态（默认不选语义）：基准的力度 options = 模型已
    // 保存的 options（模型无力度参数时为空）——与 initState 的块勾选
    // 初始值一致。
    final initialEffort = initialReasoning
        .cast<ReasoningParam?>()
        .firstWhere((p) => p?.isEffortParam ?? false, orElse: () => null);
    if (initialEffort != null) {
      initialEffort.options =
          List.of(findEffortParam(m.reasoningParams)?.options ?? const []);
    }
    if (jsonEncode(initialReasoning.map((p) => p.toMap()).toList()) !=
        jsonEncode(_reasoningParams.map((p) => p.toMap()).toList())) {
      return true;
    }
    return false;
  }

  /// 应用「力度参数遮蔽」：模型有自己的力度参数时，移除供应商的
  /// 异名力度参数（页面不显示、不持久化、不参与未保存比较）。
  /// 按参数名匹配（工作副本是 copy() 实例，不能按身份比较）。
  List<ReasoningParam> _applyEffortShadowing(
    List<ReasoningParam> merged,
    List<ReasoningParam> modelParams,
  ) {
    final modelEffort = findEffortParam(modelParams);
    if (modelEffort == null) return merged;
    final modelEffortName = modelEffort.paramName;
    return merged
        .where((p) => !p.isEffortParam || p.paramName == modelEffortName)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nameController = TextEditingController(text: m?.name ?? '');
    _modelIdController = TextEditingController(text: m?.modelId ?? '');
    final context = (m?.typeConfig['context'] as num?)?.toInt() ??
        (m?.typeConfig['maxTokens'] as num?)?.toInt();
    _contextController = TextEditingController(
      text: context != null ? context.toString() : '',
    );

    // Initialize LLM-specific params from typeConfig with toggle support
    _temperature = (m?.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7;
    _topP = (m?.typeConfig['topP'] as num?)?.toDouble() ?? 1.0;
    _frequencyPenalty =
        (m?.typeConfig['frequencyPenalty'] as num?)?.toDouble() ?? 0.0;
    _presencePenalty =
        (m?.typeConfig['presencePenalty'] as num?)?.toDouble() ?? 0.0;

    // Read enable flags from typeConfig, default to false for new models
    // (existing configs with saved flags use their saved values)
    _enableTemperature = m?.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTopP = m?.typeConfig['enableTopP'] as bool? ?? false;
    _enableFrequencyPenalty =
        m?.typeConfig['enableFrequencyPenalty'] as bool? ?? false;
    _enablePresencePenalty =
        m?.typeConfig['enablePresencePenalty'] as bool? ?? false;
    _enableMaxTokens = m?.typeConfig['enableMaxTokens'] as bool? ?? false;
    _enableSeed = m?.typeConfig['enableSeed'] as bool? ?? false;

    final maxTokens = (m?.typeConfig['maxTokens'] as num?)?.toInt();
    _maxTokensController = TextEditingController(
      text: maxTokens != null ? maxTokens.toString() : '',
    );

    final seed = m?.typeConfig['seed'];
    _seedController = TextEditingController(
      text: seed != null ? seed.toString() : '',
    );

    // 端点类型覆盖（默认关 = 继承供应商）
    _overrideEndpointType = m?.endpointType != null;
    _endpointType = m?.endpointType ?? 'openai';

    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
    // 旧数据升级：非 json 类型且仅有 defaultValue（无 options）时，
    // 把 defaultValue 作为第一个选项（新 UI 为选项值胶囊块）；
    // boolean 类型无旧值时预填 true/false 两个选项。
    for (final p in _customParams) {
      if (p.type == 'json') continue;
      if (p.options.isEmpty) {
        if (p.defaultValue.trim().isNotEmpty) {
          p.options.add(p.defaultValue);
        } else if (p.type == 'boolean') {
          p.options.addAll(['true', 'false']);
        }
      }
    }
    // Initialize JSON validation for existing params
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }
    // 自定义参数勾选块状态：默认全选（json 类型用默认值输入框，不参与）
    _customParamSelectedValues.clear();
    for (final p in _customParams) {
      if (p.type == 'json') continue;
      _customParamSelectedValues[p] = p.options.toSet();
    }
    // Reasoning params: 合并视图工作副本（供应商参数 + 模型参数，
    // 同名时模型参数覆盖供应商参数，与请求构建时的合并语义一致）。
    // 无「继承/独立」标记：页面显示什么、保存就写入什么。
    final provider = widget.provider;
    _reasoningParams = mergeReasoningParams(
      provider?.reasoningParams ?? [],
      m?.reasoningParams ?? [],
    ).map((p) => p.copy()).toList();

    // 力度参数遮蔽：模型有自己的力度参数时，供应商的力度参数（可能
    // 同名或异名）被模型版本遮蔽——页面不显示它，也不应持久化它，
    // 否则会产生不可见的陈旧副本（供应商后续修改失效、保存被重名
    // 检查误拦）。仅当模型无力度参数时才保留供应商的力度参数。
    _reasoningParams = _applyEffortShadowing(
      _reasoningParams,
      m?.reasoningParams ?? [],
    );

    // 「没有就不显示」：供应商的力度参数未设置任何选项值（仅参数名）
    // 且模型也没有自己的力度参数时，模型页不显示它——力度区只在有值
    // （供应商或模型）时出现，用户可在模型页自建。
    final providerEffort = findEffortParam(provider?.reasoningParams ?? []);
    final modelEffortParam = findEffortParam(m?.reasoningParams ?? []);
    if (modelEffortParam == null &&
        (providerEffort == null || providerEffort.options.isEmpty)) {
      _reasoningParams.removeWhere((p) => p.isEffortParam);
    }

    // 推理力度「勾选块」初始化：
    // - 块顺序：模型已保存的顺序在前（模型有力度参数时），供应商
    //   独有值追加——保证「打开即未修改」比较成立（工作副本与初始
    //   合并视图一致）；
    // - 勾选 = 模型已保存的 options；模型未保存过勾选（新建模型或
    //   编辑但模型无力度参数）时默认全不选，用户显式勾选想显示的值；
    // - 供应商来源判定用于删除按钮的显隐。
    _providerEffortValues = {...providerEffort?.options ?? []};
    final modelEffortValues = modelEffortParam?.options ?? [];
    _effortBlockValues = modelEffortParam != null
        ? [
            ...modelEffortValues,
            ..._providerEffortValues
                .where((v) => !modelEffortValues.contains(v)),
          ]
        : [..._providerEffortValues];
    _effortSelectedValues =
        modelEffortParam != null ? modelEffortValues.toSet() : <String>{};

    // 初始快照（reset 还原用）
    _initialParamSnapshots = {
      for (final p in _reasoningParams) p: p.copy(),
    };
    _initialBlockValues = List.of(_effortBlockValues);
    _initialSelectedValues = {..._effortSelectedValues};

    // 附加参数「勾选块」初始化（string/number 类型）：
    // - 块顺序：模型已保存的顺序在前，供应商独有值追加；
    // - 勾选 = 模型已保存的 options；模型未保存过时默认全选供应商值
    //   （附加参数保持「选项默认有效」语义，与力度参数默认不选不同）；
    // - 供应商来源判定用于删除按钮的显隐。
    final providerByName = {
      for (final p in provider?.reasoningParams ?? [])
        if (p.paramName.trim().isNotEmpty) p.paramName.trim(): p,
    };
    _additionalBlockValues.clear();
    _additionalSelectedValues.clear();
    _providerAdditionalValues.clear();
    for (final p in _reasoningParams) {
      if (p.isReasoningToggle || p.isEffortParam) continue;
      if (p.type == 'json' || p.type == 'boolean') continue;
      final providerOptions = <String>{
        ...providerByName[p.paramName.trim()]?.options ?? const <String>[],
      };
      final modelOptions = p.options;
      _providerAdditionalValues[p] = providerOptions;
      _additionalBlockValues[p] = [
        ...modelOptions,
        ...providerOptions.where((v) => !modelOptions.contains(v)),
      ];
      _additionalSelectedValues[p] =
          modelOptions.isNotEmpty ? modelOptions.toSet() : {...providerOptions};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _contextController.dispose();
    _maxTokensController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  // ===================================================================
  // Build
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (widget.model!.name.isNotEmpty ? widget.model!.name : '编辑模型')
        : '添加模型';
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃修改？'),
            content: const Text('当前有未保存的修改，确定要放弃吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._buildBasicSettingsSection(cs),
            ..._buildReasoningSection(cs),
            ..._buildLlmParamsSection(cs),
            ..._buildCustomParamsSection(),
          ],
        ),
      ),
    );
  }
}
