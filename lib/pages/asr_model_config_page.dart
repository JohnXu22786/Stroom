import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

import '../providers/provider_config.dart';
import '../widgets/code_editor_field.dart';
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

  void _validateJsonField(int index, CustomParam param) {
    if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
      try {
        jsonDecode(param.defaultValue.trim());
        _jsonErrors.remove(index);
      } catch (e) {
        _jsonErrors[index] = formatJsonError(param.defaultValue.trim(), e);
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.modelIdRequired),
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.modelCustomParamRequired,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.modelParamDuplicate(name),
            ),
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
              content: Text(
                AppLocalizations.of(context)!
                    .modelParamJsonInvalid(name, param.defaultValue),
              ),
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
      id: widget.model?.id,
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
        ? (widget.model!.name.isNotEmpty
            ? widget.model!.name
            : AppLocalizations.of(context)!.modelEditTitle)
        : AppLocalizations.of(context)!.modelCreateTitle;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.modelDiscardTitle),
            content: Text(AppLocalizations.of(context)!.modelDiscardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.batchDlgCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(AppLocalizations.of(context)!.taskFlowUiDiscard),
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
              child: Text(AppLocalizations.of(context)!.mermaidSaveButton),
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
              AppLocalizations.of(context)!.assistantBasicTab,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),

            LabeledTextField(
              label: AppLocalizations.of(context)!.modelNameLabel,
              controller: _nameController,
              hintText: AppLocalizations.of(context)!.modelNameHint,
            ),
            const SizedBox(height: 16),

            LabeledTextField(
              label: AppLocalizations.of(context)!.modelIdLabel,
              controller: _modelIdController,
              hintText: AppLocalizations.of(context)!.asrModelIdExample,
              required: true,
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // ASR 参数设置（带开关）
            // ==========================================================
            Text(
              AppLocalizations.of(context)!.modelAsrParams,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.modelEnabledParamsHelp,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // Language
            LlmToggleTextField(
              label: AppLocalizations.of(context)!.modelAsrLanguageCode,
              controller: _languageController,
              enabled: _enableLanguage,
              onToggle: (v) => setState(() => _enableLanguage = v),
              hintText: AppLocalizations.of(context)!.asrLanguageExample,
              description: AppLocalizations.of(context)!.modelAsrLanguageHelp,
            ),

            // Response Format
            _buildResponseFormatSection(cs),

            // Temperature
            LlmToggleSlider(
              label: AppLocalizations.of(context)!.modelTemperature,
              value: _temperature,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              enabled: _enableTemperature,
              onChanged: (v) => setState(() => _temperature = v),
              onToggle: (v) => setState(() => _enableTemperature = v),
              description: AppLocalizations.of(context)!.modelTemperatureHelp,
            ),

            // Timestamp Granularities
            _buildTimestampGranularitiesSection(cs),

            // Prompt
            LlmToggleTextField(
              label: AppLocalizations.of(context)!.asrPromptLabel,
              controller: _promptController,
              enabled: _enablePrompt,
              onToggle: (v) => setState(() => _enablePrompt = v),
              hintText: AppLocalizations.of(context)!.modelAsrPromptHint,
              description: AppLocalizations.of(context)!.modelAsrPromptHelp,
            ),

            const SizedBox(height: 24),

            // ==========================================================
            // 自定义参数（总是发送）
            // ==========================================================
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.chatCustomParameters,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.assistantAddParameter,
                  ),
                  onPressed: _addCustomParam,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_customParams.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.assistantNoCustomParameters,
                    style: TextStyle(color: Colors.grey),
                  ),
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
                                  labelText: AppLocalizations.of(context)!
                                      .assistantParameterName,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText: isDuplicate
                                      ? AppLocalizations.of(context)!
                                          .modelParamExists
                                      : null,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: StroomMenuStyle.surface(
                                    context,
                                  ),
                                  borderRadius: StroomMenuStyle.borderRadius,
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
                              tooltip: AppLocalizations.of(context)!
                                  .modelParamDelete,
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
                                  labelText: AppLocalizations.of(context)!
                                      .modelParamDefaultValue,
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
                              tooltip: AppLocalizations.of(context)!
                                  .chatFullscreenEdit,
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.modelAsrResponseFormat,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                    AppLocalizations.of(context)!.modelAsrResponseHelp,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                        dropdownColor: StroomMenuStyle.surface(context),
                        borderRadius: StroomMenuStyle.borderRadius,
                        value: _responseFormat,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'json',
                            child: Text(
                              AppLocalizations.of(context)!
                                  .asrResponseFormatJson,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'text',
                            child: Text(
                              AppLocalizations.of(context)!
                                  .asrResponseFormatText,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'srt',
                            child: Text(
                              AppLocalizations.of(context)!
                                  .asrResponseFormatSrt,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'vtt',
                            child: Text(
                              AppLocalizations.of(context)!
                                  .asrResponseFormatVtt,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'verbose_json',
                            child: Text(
                              AppLocalizations.of(context)!
                                  .asrResponseFormatVerbose,
                            ),
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
                        AppLocalizations.of(context)!.asrVerboseTimestampHelp,
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.modelAsrTimestampGranularity,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                    AppLocalizations.of(context)!.modelAsrVerboseHelp,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                        dropdownColor: StroomMenuStyle.surface(context),
                        borderRadius: StroomMenuStyle.borderRadius,
                        value: _timestampGranularities,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'segment',
                            child: Text(
                              AppLocalizations.of(context)!.asrTimestampSegment,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'word',
                            child: Text(
                              AppLocalizations.of(context)!.asrTimestampWord,
                            ),
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
                    AppLocalizations.of(context)!.asrWordTimestampHelp,
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
