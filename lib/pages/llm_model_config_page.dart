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

  /// 打开页面时从供应商继承的参数名集合（合并视图中的继承部分，
  /// 不含被模型同名覆盖的；随后被认领的参数名仍在此集合中）。
  /// 用于隐藏「删除」按钮：供应商参数只能覆盖、不能删除——删除模型
  /// 副本后参数会重新继承回来，删除按钮会造成「删除无效」的错觉。
  late final Set<String> _providerInheritedNames;

  /// 打开页面时各继承参数的工作副本 → 供应商侧原始内容（按实例身份
  /// 索引）。用于「认领回退」：编辑又被还原成与供应商原值一致时，参数
  /// 保持继承状态（不写入模型），避免出现「改了又改回去却无法保存」的
  /// 死局。按身份索引保证：只有初始就是继承状态的参数可回退，且改名后
  /// 不会误匹配到其他供应商参数。
  late final Map<ReasoningParam, ReasoningParam> _providerOriginals;

  /// 被排序操作强制认领的参数（本会话内不回退为继承）。
  /// 排序结果没有内容载体（toMap 不含列表位置），内容还原不能撤销
  /// 排序造成的认领，否则排序会随保存静默丢失。
  final Set<ReasoningParam> _forceClaimedParamsStore = {};

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
      if (_reasoningParams
          .any((p) => !p.inheritedFromProvider && p.paramName.isNotEmpty)) {
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
    // Reasoning params: 仅比较模型自有（非继承）参数。继承自供应商且
    // 未修改的参数不写入模型，不视为改动；修改过的（已被认领）参数
    // 会进入自有子集参与比较。
    final originalReasoning = m.reasoningParams.map((p) => p.toMap()).toList();
    final currentReasoning = _reasoningParams
        .where((p) => !p.inheritedFromProvider)
        .map((p) => p.toMap())
        .toList();
    if (jsonEncode(originalReasoning) != jsonEncode(currentReasoning)) {
      return true;
    }
    return false;
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
    // Initialize JSON validation for existing params
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }
    // Reasoning params: 模型自身参数 + 供应商参数（继承视图，实时同步）。
    // 与供应商参数同名的模型参数覆盖供应商参数（与请求构建时的合并
    // 语义一致，见 mergeReasoningParams）。供应商参数以 inheritedFromProvider
    // 标记，首次编辑即变为模型独立配置，保存时才写入模型。
    final provider = widget.provider;
    final modelNames = (m?.reasoningParams ?? [])
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    // 供应商参数中未被模型同名覆盖的部分 = 继承参数
    _providerInheritedNames = (provider?.reasoningParams ?? [])
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty && !modelNames.contains(n))
        .toSet();
    _reasoningParams = mergeReasoningParams(
      provider?.reasoningParams ?? [],
      m?.reasoningParams ?? [],
    ).map((p) {
      final copy = p.copy();
      copy.inheritedFromProvider =
          _providerInheritedNames.contains(p.paramName.trim());
      return copy;
    }).toList();
    // 记录继承参数的工作副本 → 供应商原值（按实例身份，认领回退用；
    // 新建的参数不是 key，不会被误标为继承）
    final providerByName = {
      for (final p in provider?.reasoningParams ?? [])
        if (p.paramName.trim().isNotEmpty) p.paramName.trim(): p,
    };
    _providerOriginals = {
      for (final copy in _reasoningParams)
        if (copy.inheritedFromProvider)
          copy: providerByName[copy.paramName.trim()]!,
    };
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
