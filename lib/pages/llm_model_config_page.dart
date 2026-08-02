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

  const LlmModelConfigPage({super.key, this.model});

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
      if (_reasoningParams.any((p) => p.paramName.isNotEmpty)) return true;
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
    if (_contextController.text !=
        ((m.typeConfig['context'] as num?)?.toInt().toString() ?? '')) {
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
    final originalCustom = m.customParams.map((p) => p.toMap()).toList();
    final currentCustom = _customParams.map((p) => p.toMap()).toList();
    if (originalCustom.toString() != currentCustom.toString()) return true;
    final originalReasoning = m.reasoningParams.map((p) => p.toMap()).toList();
    final currentReasoning = _reasoningParams.map((p) => p.toMap()).toList();
    if (originalReasoning.toString() != currentReasoning.toString()) {
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
    if (m != null) {
      _reasoningParams = m.reasoningParams.map((p) => p.copy()).toList();
    } else {
      // New model: start with no reasoning params.
      // User must explicitly add toggle, effort, and additional params
      // via the respective add buttons.
      _reasoningParams = [];
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
