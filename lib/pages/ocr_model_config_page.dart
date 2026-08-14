import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import '../widgets/code_editor_field.dart';
import 'llm_model_config_shared.dart';

/// OCR 模型配置编辑页面
/// 包含基本设置、OCR 参数（temperature/topP/maxTokens）
/// 和自定义参数；所有参数均为可选，未开启/未填写则不发送。
///
/// 识别指令为通用设置，在文字识别页（OcrPage）统一配置，
/// 不再按模型设置。
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
  late List<CustomParam> _customParams;
  final Map<int, String?> _jsonErrors = {};

  // Slider values
  double _temperature = 0.0;
  double _topP = 1.0;

  // Toggle flags
  bool _enableTemperature = false;
  bool _enableTopP = false;
  bool _enableMaxTokens = false;

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
      if (_enableTemperature || _enableTopP || _enableMaxTokens) {
        return true;
      }
      if (_maxTokensController.text.isNotEmpty) return true;
      if (_temperature != 0.0) return true;
      if (_topP != 1.0) return true;
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
    if ((m.typeConfig['maxTokens']?.toString() ?? '') !=
        _maxTokensController.text) {
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

    // Read enable flags from typeConfig
    _enableTemperature = m?.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTopP = m?.typeConfig['enableTopP'] as bool? ?? false;
    _enableMaxTokens = m?.typeConfig['enableMaxTokens'] as bool? ?? false;

    final maxTokens = (m?.typeConfig['maxTokens'] as num?)?.toInt();
    _maxTokensController = TextEditingController(
      text: maxTokens != null ? maxTokens.toString() : '',
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

  void _validateJsonField(int index, CustomParam param) {
    if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
      try {
        jsonDecode(param.defaultValue.trim());
        _jsonErrors.remove(index);
      } catch (e) {
        _jsonErrors[index] =
            formatJsonError(param.defaultValue.trim(), e);
      }
    } else {
      _jsonErrors.remove(index);
    }
  }

  bool _jsonParamHasError(int index) => _jsonErrors.containsKey(index);

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
    // Always save toggle states so they persist
    typeConfig['enableTemperature'] = _enableTemperature;
    typeConfig['enableTopP'] = _enableTopP;
    typeConfig['enableMaxTokens'] = _enableMaxTokens;

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

    // Instructions are now generic (configured on the OCR page, not per
    // model), so nothing instruction-related is written here. However,
    // legacy per-model instructions still stored in the original config
    // are preserved through saves — the one-shot generic-store migration
    // may not have consumed them yet (e.g. the OCR page was never opened),
    // and dropping them here would lose the user's configured instructions.
    final originalTypeConfig = widget.model?.typeConfig;
    if (originalTypeConfig != null) {
      if (originalTypeConfig['userInstructions'] is List) {
        typeConfig['userInstructions'] = originalTypeConfig['userInstructions'];
      } else if (originalTypeConfig['userInstruction'] is String) {
        typeConfig['userInstruction'] = originalTypeConfig['userInstruction'];
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
            // OCR 参数设置（全部可选）
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
              '基于 OpenAI 兼容的视觉 Chat Completions 格式（OCR 通常即调用此类'
              '接口），以下参数均为可选，不填写/不开启则不发送。其他供应商特有'
              '参数（需其接口支持）可在下方自定义参数中添加。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: param.defaultValue,
                                minLines: 4,
                                maxLines: 8,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                inputFormatters: const [
                                  CodeSmartInputFormatter(),
                                ],
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
                                  alignLabelWithHint: true,
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
                                showJsonValueEditorDialog(
                                  context,
                                  initialValue: param.defaultValue,
                                  hintText: param.paramType.defaultValueHint,
                                  type: param.type,
                                  onSave: (result) {
                                    param.defaultValue = result;
                                    _validateJsonField(i, param);
                                    setState(() {});
                                  },
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
}
