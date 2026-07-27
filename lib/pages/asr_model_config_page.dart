import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_shared.dart';

/// ASR 模型配置编辑页面
/// 包含基本设置和 ASR 专有参数（language、response_format 等）
class AsrModelConfigPage extends StatefulWidget {
  final ModelConfig? model; // null = 新建, non-null = 编辑

  const AsrModelConfigPage({super.key, this.model});

  @override
  State<AsrModelConfigPage> createState() => _AsrModelConfigPageState();
}

class _AsrModelConfigPageState extends State<AsrModelConfigPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelIdController;
  late final TextEditingController _languageController;
  late final TextEditingController _promptController;
  late List<CustomParam> _customParams;
  final Map<int, String?> _jsonErrors = {};

  // Slider values
  double _temperature = 0.0;

  // Dropdown values
  String _responseFormat = 'json';
  String _timestampGranularities = 'segment';

  // Toggle flags
  bool _enableLanguage = false;
  bool _enableResponseFormat = false;
  bool _enableTemperature = false;
  bool _enableTimestampGranularities = false;
  bool _enablePrompt = false;

  bool _isSaving = false;

  bool get _isEditing => widget.model != null;

  /// Whether the user has made unsaved changes.
  bool get _hasUnsavedChanges {
    final m = widget.model;
    if (m == null) {
      if (_nameController.text.isNotEmpty) return true;
      if (_modelIdController.text.isNotEmpty) return true;
      if (_customParams.any((p) => p.paramName.isNotEmpty)) return true;
      if (_enableLanguage ||
          _enableResponseFormat ||
          _enableTemperature ||
          _enableTimestampGranularities ||
          _enablePrompt) {
        return true;
      }
      if (_languageController.text.isNotEmpty) return true;
      if (_promptController.text.isNotEmpty) return true;
      if (_temperature != 0.0) return true;
      if (_responseFormat != 'json') return true;
      if (_timestampGranularities != 'segment') return true;
      return false;
    }
    if (_nameController.text != m.name) return true;
    if (_modelIdController.text != m.modelId) return true;

    if ((m.typeConfig['language'] as String? ?? '') !=
        _languageController.text) {
      return true;
    }
    if ((m.typeConfig['responseFormat'] as String? ?? 'json') !=
        _responseFormat) {
      return true;
    }
    if (((m.typeConfig['temperature'] as num?)?.toDouble() ?? 0.0) !=
        _temperature) {
      return true;
    }
    if ((m.typeConfig['timestampGranularities'] as String? ?? 'segment') !=
        _timestampGranularities) {
      return true;
    }
    if ((m.typeConfig['prompt'] as String? ?? '') != _promptController.text) {
      return true;
    }
    if ((m.typeConfig['enableLanguage'] as bool? ?? false) != _enableLanguage) {
      return true;
    }
    if ((m.typeConfig['enableResponseFormat'] as bool? ?? false) !=
        _enableResponseFormat) {
      return true;
    }
    if ((m.typeConfig['enableTemperature'] as bool? ?? false) !=
        _enableTemperature) {
      return true;
    }
    if ((m.typeConfig['enableTimestampGranularities'] as bool? ?? false) !=
        _enableTimestampGranularities) {
      return true;
    }
    if ((m.typeConfig['enablePrompt'] as bool? ?? false) != _enablePrompt) {
      return true;
    }

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

    _temperature = (m?.typeConfig['temperature'] as num?)?.toDouble() ?? 0.0;
    _responseFormat = (m?.typeConfig['responseFormat'] as String?) ?? 'json';
    _timestampGranularities =
        (m?.typeConfig['timestampGranularities'] as String?) ?? 'segment';

    _enableLanguage = m?.typeConfig['enableLanguage'] as bool? ?? false;
    _enableResponseFormat =
        m?.typeConfig['enableResponseFormat'] as bool? ?? false;
    _enableTemperature = m?.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTimestampGranularities =
        m?.typeConfig['enableTimestampGranularities'] as bool? ?? false;
    _enablePrompt = m?.typeConfig['enablePrompt'] as bool? ?? false;

    _languageController = TextEditingController(
      text: m?.typeConfig['language'] as String? ?? '',
    );
    _promptController = TextEditingController(
      text: m?.typeConfig['prompt'] as String? ?? '',
    );

    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _languageController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // ===================================================================
  // 自定义参数
  // ===================================================================

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
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

    final typeConfig = <String, dynamic>{};

    // Only include enabled params
    if (_enableLanguage) {
      final lang = _languageController.text.trim();
      if (lang.isNotEmpty) {
        typeConfig['language'] = lang;
      }
    }
    if (_enableResponseFormat) {
      typeConfig['responseFormat'] = _responseFormat;
    }
    if (_enableTemperature) {
      typeConfig['temperature'] = _temperature;
    }
    if (_enableTimestampGranularities) {
      typeConfig['timestampGranularities'] = _timestampGranularities;
    }
    if (_enablePrompt) {
      final prompt = _promptController.text.trim();
      if (prompt.isNotEmpty) {
        typeConfig['prompt'] = prompt;
      }
    }

    // Always save toggle states
    typeConfig['enableLanguage'] = _enableLanguage;
    typeConfig['enableResponseFormat'] = _enableResponseFormat;
    typeConfig['enableTemperature'] = _enableTemperature;
    typeConfig['enableTimestampGranularities'] = _enableTimestampGranularities;
    typeConfig['enablePrompt'] = _enablePrompt;

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

            LabeledTextField(
              label: '模型名称',
              controller: _nameController,
              hintText: '输入显示名称（可选）',
            ),
            const SizedBox(height: 16),

            LabeledTextField(
              label: '模型 ID',
              controller: _modelIdController,
              hintText: '如 whisper-1',
              required: true,
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // ASR 参数设置（带开关）
            // ==========================================================
            Text(
              'ASR 参数',
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

            // Language
            LlmToggleTextField(
              label: '语言代码 (Language)',
              controller: _languageController,
              enabled: _enableLanguage,
              onToggle: (v) => setState(() => _enableLanguage = v),
              hintText: '如 zh, en, ja',
              description: 'ISO-639-1 语言代码，留空则由模型自动检测',
            ),

            // Response Format
            _buildResponseFormatSection(cs),

            // Temperature
            LlmToggleSlider(
              label: '温度 (Temperature)',
              value: _temperature,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              enabled: _enableTemperature,
              onChanged: (v) => setState(() => _temperature = v),
              onToggle: (v) => setState(() => _enableTemperature = v),
              description: '控制输出的随机性，推荐使用较低的数值',
            ),

            // Timestamp Granularities
            _buildTimestampGranularitiesSection(cs),

            // Prompt
            LlmToggleTextField(
              label: '提示词 (Prompt)',
              controller: _promptController,
              enabled: _enablePrompt,
              onToggle: (v) => setState(() => _enablePrompt = v),
              hintText: '输入上下文提示词（可选）',
              description: '提供上下文以改进转写准确性，如专业术语列表',
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
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(
                                            t.label,
                                            style:
                                                const TextStyle(fontSize: 13),
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

  // ===================================================================
  // Response Format 下拉选择
  // ===================================================================

  Widget _buildResponseFormatSection(ColorScheme cs) {
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
                  child: Text('响应格式 (Response Format)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _enableResponseFormat,
                  onChanged: (v) => setState(() => _enableResponseFormat = v),
                ),
              ],
            ),
            if (_enableResponseFormat)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '转写结果的返回格式',
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
                        value: _responseFormat,
                        isDense: true,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'json',
                            child: Text('json - JSON 格式'),
                          ),
                          DropdownMenuItem(
                            value: 'text',
                            child: Text('text - 纯文本'),
                          ),
                          DropdownMenuItem(
                            value: 'srt',
                            child: Text('srt - SRT 字幕'),
                          ),
                          DropdownMenuItem(
                            value: 'vtt',
                            child: Text('vtt - VTT 字幕'),
                          ),
                          DropdownMenuItem(
                            value: 'verbose_json',
                            child: Text('verbose_json - 详细 JSON（含时间戳）'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _responseFormat = v);
                          }
                        },
                      ),
                    ),
                  ),
                  if (_responseFormat == 'verbose_json')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '选择 verbose_json 后可以启用下方的时间戳粒度选项',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // Timestamp Granularities 下拉选择
  // ===================================================================

  Widget _buildTimestampGranularitiesSection(ColorScheme cs) {
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
                  child: Text('时间戳粒度 (Timestamp Granularities)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _enableTimestampGranularities,
                  onChanged: (v) =>
                      setState(() => _enableTimestampGranularities = v),
                ),
              ],
            ),
            if (_enableTimestampGranularities)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '仅在 response_format 为 verbose_json 时生效',
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
                        value: _timestampGranularities,
                        isDense: true,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'segment',
                            child: Text('segment - 段落级别'),
                          ),
                          DropdownMenuItem(
                            value: 'word',
                            child: Text('word - 单词级别'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _timestampGranularities = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '注意：单词级时间戳的准确性可能低于段落级',
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
