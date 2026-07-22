import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_shared.dart';

/// OCR 模型配置编辑页面
/// 包含基本设置和 OCR 专有参数（temperature、detail 等）
class OcrModelConfigPage extends StatefulWidget {
  final ModelConfig? model; // null = 新建, non-null = 编辑

  const OcrModelConfigPage({super.key, this.model});

  @override
  State<OcrModelConfigPage> createState() => _OcrModelConfigPageState();
}

class _OcrModelConfigPageState extends State<OcrModelConfigPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelIdController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _seedController;
  late final TextEditingController _stopController;
  late List<CustomParam> _customParams;
  final Map<int, String?> _jsonErrors = {};

  // Slider values
  double _temperature = 0.0;
  double _topP = 1.0;
  double _frequencyPenalty = 0.0;
  double _presencePenalty = 0.0;

  // Detail level
  String _detail = 'high';

  // Toggle flags
  bool _enableTemperature = false;
  bool _enableTopP = false;
  bool _enableMaxTokens = false;
  bool _enableDetail = false;
  bool _enableSeed = false;
  bool _enableFrequencyPenalty = false;
  bool _enablePresencePenalty = false;
  bool _enableStop = false;

  bool _isSaving = false;

  bool get _isEditing => widget.model != null;

  /// Whether the user has made unsaved changes.
  bool get _hasUnsavedChanges {
    final m = widget.model;
    if (m == null) {
      // New model: check if any field is non-empty or any param changed
      if (_nameController.text.isNotEmpty) return true;
      if (_modelIdController.text.isNotEmpty) return true;
      if (_customParams.any((p) => p.paramName.isNotEmpty)) return true;
      if (_enableTemperature ||
          _enableTopP ||
          _enableMaxTokens ||
          _enableDetail ||
          _enableSeed ||
          _enableFrequencyPenalty ||
          _enablePresencePenalty ||
          _enableStop) {
        return true;
      }
      if (_maxTokensController.text.isNotEmpty) return true;
      if (_seedController.text.isNotEmpty) return true;
      if (_stopController.text.isNotEmpty) return true;
      if (_temperature != 0.0) return true;
      if (_topP != 1.0) return true;
      if (_frequencyPenalty != 0.0) return true;
      if (_presencePenalty != 0.0) return true;
      if (_detail != 'high') return true;
      return false;
    }
    // Editing: compare against original model
    if (_nameController.text != m.name) return true;
    if (_modelIdController.text != m.modelId) return true;

    // OCR params
    if (((m.typeConfig['temperature'] as num?)?.toDouble() ?? 0.0) !=
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
    if ((m.typeConfig['detail'] as String? ?? 'high') != _detail) {
      return true;
    }
    if ((m.typeConfig['enableTemperature'] as bool? ?? false) !=
        _enableTemperature) {
      return true;
    }
    if ((m.typeConfig['enableTopP'] as bool? ?? false) != _enableTopP) {
      return true;
    }
    if ((m.typeConfig['enableMaxTokens'] as bool? ?? false) !=
        _enableMaxTokens) {
      return true;
    }
    if ((m.typeConfig['enableDetail'] as bool? ?? false) != _enableDetail) {
      return true;
    }
    if ((m.typeConfig['enableSeed'] as bool? ?? false) != _enableSeed) {
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
    if ((m.typeConfig['enableStop'] as bool? ?? false) != _enableStop) {
      return true;
    }
    if ((m.typeConfig['maxTokens']?.toString() ?? '') !=
        _maxTokensController.text) {
      return true;
    }
    if ((m.typeConfig['seed']?.toString() ?? '') != _seedController.text) {
      return true;
    }
    if ((m.typeConfig['stop'] as String? ?? '') != _stopController.text) {
      return true;
    }
    // Custom params (simple check via serialization)
    final originalCustom = m.customParams.map((p) => p.toMap()).toList();
    final currentCustom = _customParams.map((p) => p.toMap()).toList();
    if (originalCustom.toString() != currentCustom.toString()) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nameController = TextEditingController(text: m?.name ?? '');
    _modelIdController = TextEditingController(text: m?.modelId ?? '');

    // Initialize OCR-specific params from typeConfig
    _temperature = (m?.typeConfig['temperature'] as num?)?.toDouble() ?? 0.0;
    _topP = (m?.typeConfig['topP'] as num?)?.toDouble() ?? 1.0;
    _frequencyPenalty =
        (m?.typeConfig['frequencyPenalty'] as num?)?.toDouble() ?? 0.0;
    _presencePenalty =
        (m?.typeConfig['presencePenalty'] as num?)?.toDouble() ?? 0.0;
    _detail = (m?.typeConfig['detail'] as String?) ?? 'high';

    // Read enable flags from typeConfig
    _enableTemperature = m?.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTopP = m?.typeConfig['enableTopP'] as bool? ?? false;
    _enableMaxTokens = m?.typeConfig['enableMaxTokens'] as bool? ?? false;
    _enableDetail = m?.typeConfig['enableDetail'] as bool? ?? false;
    _enableSeed = m?.typeConfig['enableSeed'] as bool? ?? false;
    _enableFrequencyPenalty =
        m?.typeConfig['enableFrequencyPenalty'] as bool? ?? false;
    _enablePresencePenalty =
        m?.typeConfig['enablePresencePenalty'] as bool? ?? false;
    _enableStop = m?.typeConfig['enableStop'] as bool? ?? false;

    final maxTokens = (m?.typeConfig['maxTokens'] as num?)?.toInt();
    _maxTokensController = TextEditingController(
      text: maxTokens != null ? maxTokens.toString() : '',
    );

    final seed = m?.typeConfig['seed'];
    _seedController = TextEditingController(
      text: seed != null ? seed.toString() : '',
    );

    _stopController = TextEditingController(
      text: m?.typeConfig['stop'] as String? ?? '',
    );

    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
    // Initialize JSON validation for existing params
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _maxTokensController.dispose();
    _seedController.dispose();
    _stopController.dispose();
    super.dispose();
  }

  // ===================================================================
  // 自定义参数
  // ===================================================================

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
      // Shift existing error keys by +1 since a new param was inserted at 0
      final newErrors = <int, String?>{};
      for (final entry in _jsonErrors.entries) {
        newErrors[entry.key + 1] = entry.value;
      }
      _jsonErrors
        ..clear()
        ..addAll(newErrors);
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
      _jsonErrors.remove(index);
      // Shift indices after removal
      final newErrors = <int, String?>{};
      for (final entry in _jsonErrors.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newErrors[newKey] = entry.value;
      }
      _jsonErrors
        ..clear()
        ..addAll(newErrors);
    });
  }

  String _formatJsonError(String source, dynamic error) {
    if (error is FormatException) {
      final offset = error.offset;
      final msg = error.message;
      if (offset != null && offset >= 0 && offset <= source.length) {
        final before = source.substring(0, offset);
        final lines = before.split('\n');
        final line = lines.length;
        final col = lines.last.length + 1;
        return '第 $line 行第 $col 列: $msg';
      }
      return 'JSON 格式错误: $msg';
    }
    return 'JSON 格式不正确';
  }

  void _validateJsonField(int index, CustomParam param) {
    if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
      try {
        jsonDecode(param.defaultValue.trim());
        _jsonErrors.remove(index);
      } catch (e) {
        _jsonErrors[index] = _formatJsonError(param.defaultValue, e);
      }
    } else {
      _jsonErrors.remove(index);
    }
  }

  bool _jsonParamHasError(int index) => _jsonErrors.containsKey(index);

  Widget _buildCodeEditorTextField(
    TextEditingController controller,
    String hintText,
    String type,
  ) {
    final lines = controller.text.split('\n');
    final lineCount = lines.length;
    final digitCount = lineCount.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 20.0).clamp(36.0, 80.0);
    const lineHeight = 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers
        Container(
          width: lineNumWidth,
          padding: const EdgeInsets.only(top: 12, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(lineCount, (i) {
              return SizedBox(
                height: lineHeight,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
              );
            }),
          ),
        ),
        Container(width: 1, color: Colors.grey.shade300),
        // Editable text area
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.3,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(8, 11, 8, 12),
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }

  void _showValueFullscreenEditor(
    BuildContext context,
    String currentValue,
    ValueChanged<String> onSave,
    String hintText, {
    String type = 'string',
  }) {
    final editingController = TextEditingController(text: currentValue);
    String? liveError;

    void validateLive() {
      if (type == 'json' && editingController.text.trim().isNotEmpty) {
        try {
          jsonDecode(editingController.text.trim());
          liveError = null;
        } catch (e) {
          liveError = _formatJsonError(editingController.text, e);
        }
      } else {
        liveError = null;
      }
    }

    validateLive();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Title bar
                Row(
                  children: [
                    Icon(
                      type == 'json' ? Icons.data_object : Icons.edit_note,
                      size: 20,
                      color: type == 'json' ? Colors.amber.shade700 : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '编辑参数值',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (type == 'json')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'JSON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        editingController.dispose();
                        Navigator.pop(ctx);
                      },
                      tooltip: '取消',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Code editor area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f5f5),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCodeEditorTextField(
                      editingController,
                      hintText,
                      type,
                    ),
                  ),
                ),
                // Error message bar
                if (liveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              liveError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  children: [
                    if (liveError != null)
                      Text(
                        'JSON 格式有误，请修正后再保存',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        editingController.dispose();
                        Navigator.pop(ctx);
                      },
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('确定'),
                      onPressed: liveError != null
                          ? null
                          : () {
                              final text = editingController.text;
                              editingController.dispose();
                              Navigator.pop(ctx);
                              onSave(text);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
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

    // 验证自定义参数：参数名和默认值不能为空，参数名不能重复，
    // 且 JSON 类型的默认值必须是合法 JSON
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
      // JSON 类型的默认值必须是合法 JSON
      if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
        try {
          jsonDecode(param.defaultValue.trim());
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('参数 "$name" 的默认值不是合法 JSON：${param.defaultValue}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    var name = _nameController.text.trim();
    if (name.isEmpty && modelId.isNotEmpty) {
      name = modelId;
    }

    // Build typeConfig with OCR-specific params (with toggles)
    final typeConfig = <String, dynamic>{};

    // Only include enabled params
    if (_enableTemperature) {
      typeConfig['temperature'] = _temperature;
    }
    if (_enableTopP) {
      typeConfig['topP'] = _topP;
    }
    if (_enableDetail) {
      typeConfig['detail'] = _detail;
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
    typeConfig['enableMaxTokens'] = _enableMaxTokens;
    typeConfig['enableDetail'] = _enableDetail;
    typeConfig['enableSeed'] = _enableSeed;
    typeConfig['enableFrequencyPenalty'] = _enableFrequencyPenalty;
    typeConfig['enablePresencePenalty'] = _enablePresencePenalty;
    typeConfig['enableStop'] = _enableStop;

    // Parse optional maxTokens
    final maxTokensStr = _maxTokensController.text.trim();
    if (maxTokensStr.isNotEmpty) {
      final maxTokens = int.tryParse(maxTokensStr);
      if (maxTokens == null || maxTokens <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最大 Token 数必须为正整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      typeConfig['maxTokens'] = maxTokens;
    } else if (_enableMaxTokens) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('最大 Token 数已启用但未填写'),
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

    // Parse optional stop sequences — only save when toggle is on
    if (_enableStop) {
      final stopStr = _stopController.text.trim();
      if (stopStr.isNotEmpty) {
        typeConfig['stop'] = stopStr;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('停止序列已启用但未填写'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
    }

    final result = ModelConfig(
      name: name,
      modelId: modelId,
      typeConfig: typeConfig,
      customParams: _customParams.map((p) => p.copy()).toList(),
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
            Text(
              '基本设置',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
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
            const SizedBox(height: 24),

            // ==========================================================
            // OCR 参数设置（带开关）
            // ==========================================================
            Text(
              'OCR 参数',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '开启的参数将作为默认值发送到 API 请求中',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
              description: '控制输出的随机性，OCR 推荐使用较低的数值',
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
              label: '最大 Token 数',
              controller: _maxTokensController,
              enabled: _enableMaxTokens,
              onToggle: (v) => setState(() => _enableMaxTokens = v),
              hintText: '如 4096',
              keyboardType: TextInputType.number,
              description: '每次响应最多生成的 token 数',
            ),

            // Seed
            LlmToggleTextField(
              label: '随机种子 (Seed)',
              controller: _seedController,
              enabled: _enableSeed,
              onToggle: (v) => setState(() => _enableSeed = v),
              hintText: '如 42',
              keyboardType: TextInputType.number,
              description: '设置后可使输出结果可复现',
            ),

            // Detail level
            _buildDetailSection(cs),

            // Stop sequences
            LlmToggleTextField(
              label: '停止序列 (Stop)',
              controller: _stopController,
              enabled: _enableStop,
              onToggle: (v) => setState(() => _enableStop = v),
              hintText: '用逗号分隔多个停止词',
              description: '遇到这些序列时停止生成',
            ),

            const SizedBox(height: 24),

            // ==========================================================
            // 自定义参数（总是发送）
            // ==========================================================
            Row(
              children: [
                const Text(
                  '自定义参数',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
                    _customParams.indexWhere(
                          (p) => p.paramName.trim() == name,
                        ) !=
                        i;
                return Card(
                  key: ObjectKey(param),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: param.type,
                                  isDense: true,
                                  items: ParamType.values
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(
                                            t.label,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        param.type = v;
                                        _validateJsonField(i, param);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _removeCustomParam(i),
                              tooltip: '删除参数',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: param.defaultValue,
                                decoration: InputDecoration(
                                  labelText: '默认参数值',
                                  hintText: param.paramType.defaultValueHint,
                                  border: const OutlineInputBorder(),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _jsonParamHasError(i)
                                          ? Colors.red
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                    ),
                                  ),
                                  errorText: _jsonErrors[i],
                                  errorMaxLines: 3,
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  param.defaultValue = v;
                                  _validateJsonField(i, param);
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.fullscreen, size: 20),
                              tooltip: '全屏编辑',
                              onPressed: () {
                                _showValueFullscreenEditor(
                                  context,
                                  param.defaultValue,
                                  (result) {
                                    param.defaultValue = result;
                                    _validateJsonField(i, param);
                                    setState(() {});
                                  },
                                  param.paramType.defaultValueHint,
                                  type: param.type,
                                );
                              },
                            ),
                          ],
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

  /// Build the Detail level card with dropdown.
  Widget _buildDetailSection(ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('图片细节级别 (Detail)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _enableDetail,
                  onChanged: (v) => setState(() => _enableDetail = v),
                ),
              ],
            ),
            if (_enableDetail)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '控制模型处理图片时的分辨率',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _detail,
                        isDense: true,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text('auto - 自动选择'),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('low - 低分辨率 (512x512)'),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('high - 高分辨率 (分块处理)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _detail = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detail == 'auto'
                        ? '模型根据图片大小自动选择细节级别'
                        : _detail == 'low'
                            ? '低分辨率模式，处理速度更快、消耗更少 Token'
                            : '高分辨率模式，模型将图片分块处理以获取更多细节',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
