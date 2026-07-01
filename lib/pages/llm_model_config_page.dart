import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_shared.dart';

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
          _enableSeed) return true;
      if (_maxTokensController.text.isNotEmpty) return true;
      if (_seedController.text.isNotEmpty) return true;
      if (_temperature != 0.7) return true;
      if (_topP != 1.0) return true;
      if (_frequencyPenalty != 0.0) return true;
      if (_presencePenalty != 0.0) return true;
      return false;
    }
    // Editing: compare against original model
    if (_nameController.text != m.name) return true;
    if (_modelIdController.text != m.modelId) return true;
    if (_contextController.text !=
        ((m.typeConfig['context'] as num?)?.toInt()?.toString() ?? ''))
      return true;
    // LLM params
    if (((m.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7) !=
        _temperature) return true;
    if (((m.typeConfig['topP'] as num?)?.toDouble() ?? 1.0) != _topP)
      return true;
    if (((m.typeConfig['frequencyPenalty'] as num?)?.toDouble() ?? 0.0) !=
        _frequencyPenalty) return true;
    if (((m.typeConfig['presencePenalty'] as num?)?.toDouble() ?? 0.0) !=
        _presencePenalty) return true;
    if ((m.typeConfig['enableTemperature'] as bool? ?? false) !=
        _enableTemperature) return true;
    if ((m.typeConfig['enableTopP'] as bool? ?? false) != _enableTopP)
      return true;
    if ((m.typeConfig['enableFrequencyPenalty'] as bool? ?? false) !=
        _enableFrequencyPenalty) return true;
    if ((m.typeConfig['enablePresencePenalty'] as bool? ?? false) !=
        _enablePresencePenalty) return true;
    if ((m.typeConfig['enableMaxTokens'] as bool? ?? false) != _enableMaxTokens)
      return true;
    if ((m.typeConfig['enableSeed'] as bool? ?? false) != _enableSeed)
      return true;
    if ((m.typeConfig['maxTokens']?.toString() ?? '') !=
        _maxTokensController.text) return true;
    if ((m.typeConfig['seed']?.toString() ?? '') != _seedController.text)
      return true;
    // Custom params and reasoning params (simple check via serialization)
    final originalCustom = m.customParams.map((p) => p.toMap()).toList();
    final currentCustom = _customParams.map((p) => p.toMap()).toList();
    if (originalCustom.toString() != currentCustom.toString()) return true;
    final originalReasoning = m.reasoningParams.map((p) => p.toMap()).toList();
    final currentReasoning = _reasoningParams.map((p) => p.toMap()).toList();
    if (originalReasoning.toString() != currentReasoning.toString())
      return true;
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
    _contextController =
        TextEditingController(text: context != null ? context.toString() : '');

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
        text: maxTokens != null ? maxTokens.toString() : '');

    final seed = m?.typeConfig['seed'];
    _seedController =
        TextEditingController(text: seed != null ? seed.toString() : '');

    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
    _reasoningParams = (m?.reasoningParams ?? []).map((p) => p.copy()).toList();
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
  // 自定义参数
  // ===================================================================

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  // ===================================================================
  // 推理参数
  // ===================================================================

  void _addReasoningParam() {
    setState(() {
      _reasoningParams
          .add(ReasoningParam(paramName: '', enabled: false, options: []));
    });
  }

  void _removeReasoningParam(int index) {
    setState(() {
      _reasoningParams.removeAt(index);
    });
  }

  void _addOptionToParam(int paramIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.add('');
    });
  }

  void _removeOptionFromParam(int paramIndex, int optionIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.removeAt(optionIndex);
    });
  }

  // ===================================================================
  // 推理参数帮助方法
  // ===================================================================

  /// Returns reasoning params that are NOT the toggle (additional params).
  List<ReasoningParam> get _additionalReasoningParams =>
      _reasoningParams.where((p) => !p.isReasoningToggle).toList();

  /// Returns the reasoning toggle param, or null if none exists.
  ReasoningParam? get _toggleReasoningParam =>
      _reasoningParams.cast<ReasoningParam?>().firstWhere(
            (p) => p?.isReasoningToggle ?? false,
            orElse: () => null,
          );

  /// Builds the reasoning toggle card section.
  Widget _buildReasoningToggleSection(ColorScheme cs) {
    final toggle = _toggleReasoningParam;
    if (toggle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Center(
              child: Text('暂无推理开关',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加推理开关', style: TextStyle(fontSize: 13)),
                onPressed: () {
                  setState(() {
                    _reasoningParams.insert(
                        0,
                        ReasoningParam(
                          paramName: '',
                          isReasoningToggle: true,
                          onValue: '',
                          offValue: '',
                          options: [],
                        ));
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.toggle_on_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('推理开关',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      )),
                ),
                // 参数值类型选择
                _buildTypeDropdown(toggle, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () =>
                      _removeReasoningParam(_reasoningParams.indexOf(toggle)),
                  tooltip: '删除推理开关',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: toggle.paramName,
              decoration: InputDecoration(
                labelText: '参数名',
                hintText: '如 thinking.type、reasoning',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                toggle.paramName = v;
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: toggle.onValue ?? '',
                    decoration: InputDecoration(
                      labelText: '开启时值',
                      hintText: '如 enabled、true',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      toggle.onValue = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: toggle.offValue ?? '',
                    decoration: InputDecoration(
                      labelText: '关闭时值',
                      hintText: '如 disabled、false',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      toggle.offValue = v;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '推理开关打开时发送「${toggle.onValue ?? ''}」，'
              '关闭时发送「${toggle.offValue ?? ''}」',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a type dropdown for a reasoning param.
  Widget _buildTypeDropdown(ReasoningParam param, ColorScheme cs) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ParamType.values.any((t) => t.value == param.type)
              ? param.type
              : 'string',
          isDense: true,
          items: ParamType.values
              .map((t) => DropdownMenuItem(
                    value: t.value,
                    child: Text(t.label, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => param.type = v);
            }
          },
        ),
      ),
    );
  }

  /// Builds a card for an additional (non-toggle) reasoning parameter.
  Widget _buildAdditionalReasoningParamCard(
      ReasoningParam param, int actualIndex, int displayIndex, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: param.paramName,
                    decoration: InputDecoration(
                      labelText: '参数名（支持点号嵌套）',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: '如 thinking.type 或 reasoning_effort',
                    ),
                    onChanged: (v) {
                      param.paramName = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 参数值类型选择
                _buildTypeDropdown(param, cs),
                const SizedBox(width: 4),
                Switch(
                  value: param.enabled,
                  onChanged: (v) {
                    setState(() => param.enabled = v);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeReasoningParam(actualIndex),
                  tooltip: '删除参数',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('选项值',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            Text(
              '这些选项将按顺序显示在推理面板中供选择',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(param.options.length, (j) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: param.options[j],
                        decoration: InputDecoration(
                          labelText: '选项 ${j + 1}',
                          hintText: '如 low, enabled, true, max',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          param.options[j] = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (param.options.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.red, size: 18),
                        onPressed: () => _removeOptionFromParam(actualIndex, j),
                        tooltip: '删除选项',
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加选项', style: TextStyle(fontSize: 13)),
              onPressed: () => _addOptionToParam(actualIndex),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 保存
  // ===================================================================

  void _save() {
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入模型 ID'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final contextStr = _contextController.text.trim();
    if (contextStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('上下文长度为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final contextValue = int.tryParse(contextStr);
    if (contextValue == null || contextValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('上下文长度必须为正整数'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证自定义参数：参数名和默认值不能为空，参数名不能重复
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      if (name.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $name'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 验证推理参数
    // Check 1: If there are any reasoning params, the toggle must exist and be filled
    final toggleParam = _reasoningParams.cast<ReasoningParam?>().firstWhere(
          (p) => p?.isReasoningToggle ?? false,
          orElse: () => null,
        );
    final hasNonToggleParams =
        _reasoningParams.any((p) => !p.isReasoningToggle && p.paramName.trim().isNotEmpty);

    if (hasNonToggleParams && (toggleParam == null || !toggleParam.isFilledToggle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('推理开关必须先填写完整，其他推理参数才能生效'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check 2: Validate each param individually
    for (int i = 0; i < _reasoningParams.length; i++) {
      final param = _reasoningParams[i];
      final error = param.validationError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数错误：$error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Check 3: Duplicate name check across all reasoning params
    final reasoningSeenNames = <String>{};
    for (int i = 0; i < _reasoningParams.length; i++) {
      final name = _reasoningParams[i].paramName.trim();
      if (name.isEmpty) continue; // Empty names are caught by validationError above
      if (!reasoningSeenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数存在重名: $name'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    var name = _nameController.text.trim();
    if (name.isEmpty && modelId.isNotEmpty) {
      name = modelId;
    }

    // Build typeConfig with context and all LLM-specific params (with toggles)
    final typeConfig = <String, dynamic>{
      'context': contextValue,
    };

    // Only include enabled params
    if (_enableTemperature) {
      typeConfig['temperature'] = _temperature;
    }
    if (_enableTopP) {
      typeConfig['topP'] = _topP;
    }
    if (_enableFrequencyPenalty) {
      typeConfig['frequencyPenalty'] = _frequencyPenalty;
    }
    if (_enablePresencePenalty) {
      typeConfig['presencePenalty'] = _presencePenalty;
    }

    // Always save toggle states so they persist
    typeConfig['enableTemperature'] = _enableTemperature;
    typeConfig['enableTopP'] = _enableTopP;
    typeConfig['enableFrequencyPenalty'] = _enableFrequencyPenalty;
    typeConfig['enablePresencePenalty'] = _enablePresencePenalty;
    typeConfig['enableMaxTokens'] = _enableMaxTokens;
    typeConfig['enableSeed'] = _enableSeed;

    // Parse optional maxTokens
    final maxTokensStr = _maxTokensController.text.trim();
    if (maxTokensStr.isNotEmpty) {
      final maxTokens = int.tryParse(maxTokensStr);
      if (maxTokens == null || maxTokens <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最大输出 Token 数必须为正整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      typeConfig['maxTokens'] = maxTokens;
    } else if (_enableMaxTokens) {
      // If enabled but empty, show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('最大输出 Token 数已启用但未填写'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Parse optional seed
    final seedStr = _seedController.text.trim();
    if (seedStr.isNotEmpty) {
      final seed = int.tryParse(seedStr);
      if (seed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('随机种子必须为整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      typeConfig['seed'] = seed;
    } else if (_enableSeed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('随机种子已启用但未填写'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    final result = ModelConfig(
      name: name,
      modelId: modelId,
      typeConfig: typeConfig,
      customParams: _customParams.map((p) => p.copy()).toList(),
      reasoningParams: _reasoningParams.map((p) => p.copy()).toList(),
    );

    Navigator.pop(context, result);
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
            // ==========================================================
            // 基本设置
            // ==========================================================
            Text('基本设置',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.primary)),
            const SizedBox(height: 12),

            // 模型名称
            LabeledTextField(
              label: '模型名称',
              controller: _nameController,
              hintText: '输入显示名称（可选）',
            ),
            const SizedBox(height: 16),

            // 模型 ID
            LabeledTextField(
              label: '模型 ID',
              controller: _modelIdController,
              hintText: '如 gpt-4o',
              required: true,
            ),
            const SizedBox(height: 16),

            // 上下文长度
            LabeledTextField(
              label: '上下文长度',
              controller: _contextController,
              hintText: '输入上下文长度',
              required: true,
              keyboardType: TextInputType.number,
              description: '模型的最大上下文窗口大小（token 数）',
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // 推理参数（可开关，每个参数独立控制）
            // ==========================================================
            Text('推理参数',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.primary)),
            const SizedBox(height: 4),
            Text(
              '推理开关控制聊天页面中推理功能的开启和关闭，由您定义参数名和对应的开/关值。'
              '附加推理参数可添加多个，每个含参数名和可选项，显示在推理面板中供选择。'
              '参数名支持点号嵌套（如 thinking.type 会展开为 {"thinking": {"type": "..."}}）。',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // 推理开关 — 单独渲染，始终在第一个位置
            _buildReasoningToggleSection(cs),

            // 附加推理参数
            if (_additionalReasoningParams.isNotEmpty)
              ...List.generate(_additionalReasoningParams.length, (i) {
                final param = _additionalReasoningParams[i];
                final actualIndex = _reasoningParams.indexOf(param);
                return _buildAdditionalReasoningParamCard(
                    param, actualIndex, i, cs);
              }),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加推理参数'),
                onPressed: _addReasoningParam,
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // LLM 参数设置（带开关）
            // ==========================================================
            Text('LLM 参数',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.primary)),
            const SizedBox(height: 4),
            Text(
              '开启的参数将作为默认值发送到 API 请求中',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Temperature
            LlmToggleSlider(
              label: '温度 (Temperature)',
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              enabled: _enableTemperature,
              onChanged: (v) => setState(() => _temperature = v),
              onToggle: (v) => setState(() => _enableTemperature = v),
              description: '控制输出的随机性，值越高越有创造性',
            ),

            // Top P
            LlmToggleSlider(
              label: 'Top P',
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              enabled: _enableTopP,
              onChanged: (v) => setState(() => _topP = v),
              onToggle: (v) => setState(() => _enableTopP = v),
              description: '核采样参数，控制词汇选择的累积概率',
            ),

            // Frequency Penalty
            LlmToggleSlider(
              label: '频率惩罚 (Frequency Penalty)',
              value: _frequencyPenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              enabled: _enableFrequencyPenalty,
              onChanged: (v) => setState(() => _frequencyPenalty = v),
              onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
              description: '减少重复词的频率，负值增加重复',
            ),

            // Presence Penalty
            LlmToggleSlider(
              label: '存在惩罚 (Presence Penalty)',
              value: _presencePenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              enabled: _enablePresencePenalty,
              onChanged: (v) => setState(() => _presencePenalty = v),
              onToggle: (v) => setState(() => _enablePresencePenalty = v),
              description: '鼓励讨论新话题，负值鼓励重复话题',
            ),

            // Max Tokens
            LlmToggleTextField(
              label: '最大输出 Token 数',
              controller: _maxTokensController,
              enabled: _enableMaxTokens,
              onToggle: (v) => setState(() => _enableMaxTokens = v),
              hintText: '可选，如 4096',
              keyboardType: TextInputType.number,
              description: '每次响应最多生成的 token 数',
            ),

            // Seed
            LlmToggleTextField(
              label: '随机种子 (Seed)',
              controller: _seedController,
              enabled: _enableSeed,
              onToggle: (v) => setState(() => _enableSeed = v),
              hintText: '可选，如 42',
              keyboardType: TextInputType.number,
              description: '设置后可使输出结果可复现',
            ),

            const SizedBox(height: 24),

            // ==========================================================
            // 自定义参数（总是发送）
            // ==========================================================
            Row(
              children: [
                const Text('自定义参数',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加参数'),
                  onPressed: _addCustomParam,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_customParams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...List.generate(_customParams.length, (i) {
                final param = _customParams[i];
                final name = param.paramName.trim();
                final isDuplicate = name.isNotEmpty &&
                    _customParams
                            .indexWhere((p) => p.paramName.trim() == name) !=
                        i;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: param.paramName,
                                decoration: InputDecoration(
                                  labelText: '参数名',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText: isDuplicate ? '已存在该参数' : null,
                                  errorStyle: const TextStyle(fontSize: 11),
                                ),
                                onChanged: (v) {
                                  param.paramName = v;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 类型选择
                            Container(
                              width: 110,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: param.type,
                                  isDense: true,
                                  items: ParamType.values
                                      .map((t) => DropdownMenuItem(
                                            value: t.value,
                                            child: Text(t.label,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => param.type = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeCustomParam(i),
                              tooltip: '删除参数',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: param.defaultValue,
                          decoration: InputDecoration(
                            labelText: '默认参数值',
                            hintText: param.paramType.defaultValueHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => param.defaultValue = v,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
