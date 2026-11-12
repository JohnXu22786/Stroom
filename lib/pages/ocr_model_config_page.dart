import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';

import '../models/ocr_batch_execution.dart';
import '../providers/provider_config.dart';
import '../widgets/code_editor_field.dart';
import 'llm_model_config_shared.dart';
import 'model_config_shared.dart';

String _requestSizeBudgetMibText(int bytes) {
  final absoluteBytes = BigInt.from(bytes).abs();
  final bytesPerMib = BigInt.from(1024 * 1024);
  final whole = absoluteBytes ~/ bytesPerMib;
  final remainder = absoluteBytes % bytesPerMib;
  final sign = bytes < 0 ? '-' : '';
  if (remainder == BigInt.zero) return '$sign$whole';

  // 1 / 2^20 is exactly 95367431640625 / 10^20. Formatting the
  // remainder this way preserves every byte without exposing double noise.
  final fraction = (remainder * BigInt.from(95367431640625))
      .toString()
      .padLeft(20, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole.$fraction';
}

double _storedSliderValue(
    Object? value, double fallback, double min, double max) {
  if (value is! num) return fallback;
  final number = value.toDouble();
  if (!number.isFinite) return fallback;
  return number.clamp(min, max).toDouble();
}

bool _isInvalidStoredSliderValue(Object? value, double min, double max) {
  if (value == null) return false;
  if (value is! num) return true;
  final number = value.toDouble();
  return !number.isFinite || number < min || number > max;
}

bool _storedSliderValueChanged(
    Object? stored, double current, double fallback) {
  if (stored == null) return current != fallback;
  if (stored is! num) return true;
  return stored.toDouble() != current;
}

/// OCR 模型配置编辑页面
/// 包含基本设置、OCR 参数（temperature/topP/maxTokens）
/// 和自定义参数；所有参数均为可选，未开启/未填写则不发送。
///
/// 识别指令为通用设置，在文字识别页（OcrPage）统一配置，
/// 不再按模型设置。
class OcrModelConfigPage extends StatefulWidget {
  final ModelConfig? model; // null = 新建, non-null = 编辑
  final int? providerRequestSizeBudgetBytes;

  const OcrModelConfigPage({
    super.key,
    this.model,
    this.providerRequestSizeBudgetBytes,
  });

  @override
  State<OcrModelConfigPage> createState() => _OcrModelConfigPageState();
}

class _OcrModelConfigPageState extends State<OcrModelConfigPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelIdController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _requestSizeBudgetController;
  late List<CustomParam> _customParams;
  final Map<int, String?> _jsonErrors = {};
  final Map<int, int> _customParamValueFieldRevisions = {};

  // Slider values
  double _temperature = 0.0;
  double _topP = 1.0;
  bool _temperatureNeedsRepair = false;
  bool _topPNeedsRepair = false;

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
      if (_customParams.any(
        (p) =>
            p.paramName.isNotEmpty ||
            p.defaultValue.isNotEmpty ||
            p.type != ParamType.string.value,
      )) {
        return true;
      }
      if (_enableTemperature || _enableTopP || _enableMaxTokens) {
        return true;
      }
      if (_maxTokensController.text.isNotEmpty) return true;
      if (_requestSizeBudgetController.text.isNotEmpty) return true;
      if (_temperature != 0.0) return true;
      if (_topP != 1.0) return true;
      return false;
    }
    // Editing: compare against original model
    if (_nameController.text != m.name) return true;
    if (_modelIdController.text != m.modelId) return true;

    // OCR params
    if (!_temperatureNeedsRepair &&
        _storedSliderValueChanged(
          m.typeConfig['temperature'],
          _temperature,
          0.0,
        )) {
      return true;
    }
    if (!_topPNeedsRepair &&
        _storedSliderValueChanged(m.typeConfig['topP'], _topP, 1.0)) {
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
    final originalRequestBudget = m.typeConfig['requestSizeBudgetBytes'];
    final originalRequestBudgetText = originalRequestBudget is num
        ? _requestSizeBudgetMibText(originalRequestBudget.toInt())
        : '';
    if (originalRequestBudgetText != _requestSizeBudgetController.text) {
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
    _nameController.addListener(_handleControllerChanged);
    _modelIdController.addListener(_handleControllerChanged);

    // Initialize OCR-specific params from typeConfig
    final temperature = m?.typeConfig['temperature'];
    _temperatureNeedsRepair = _isInvalidStoredSliderValue(
      temperature,
      0.0,
      2.0,
    );
    _temperature = _storedSliderValue(temperature, 0.0, 0.0, 2.0);
    final topP = m?.typeConfig['topP'];
    _topPNeedsRepair = _isInvalidStoredSliderValue(topP, 0.0, 1.0);
    _topP = _storedSliderValue(topP, 1.0, 0.0, 1.0);

    // Read enable flags from typeConfig
    _enableTemperature = m?.typeConfig['enableTemperature'] as bool? ?? false;
    _enableTopP = m?.typeConfig['enableTopP'] as bool? ?? false;
    _enableMaxTokens = m?.typeConfig['enableMaxTokens'] as bool? ?? false;

    final maxTokens = (m?.typeConfig['maxTokens'] as num?)?.toInt();
    _maxTokensController = TextEditingController(
      text: maxTokens != null ? maxTokens.toString() : '',
    );
    _maxTokensController.addListener(_handleControllerChanged);
    final requestSizeBudgetBytes = m?.typeConfig['requestSizeBudgetBytes'];
    _requestSizeBudgetController = TextEditingController(
      text: requestSizeBudgetBytes is num
          ? _requestSizeBudgetMibText(requestSizeBudgetBytes.toInt())
          : '',
    )..addListener(_handleControllerChanged);

    _customParams = (m?.customParams ?? []).map((p) => p.copy()).toList();
    // Initialize JSON validation for existing params
    for (int i = 0; i < _customParams.length; i++) {
      _validateJsonField(i, _customParams[i]);
    }
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleControllerChanged);
    _modelIdController.removeListener(_handleControllerChanged);
    _maxTokensController.removeListener(_handleControllerChanged);
    _requestSizeBudgetController.removeListener(_handleControllerChanged);
    _nameController.dispose();
    _modelIdController.dispose();
    _maxTokensController.dispose();
    _requestSizeBudgetController.dispose();
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
      _customParamValueFieldRevisions.clear();
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
      _customParamValueFieldRevisions.clear();
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

  String _effectiveCustomParamValue(CustomParam param) {
    if (param.type == 'json' || param.options.isEmpty) {
      return param.defaultValue;
    }
    return param.options.first;
  }

  void _setEffectiveCustomParamValue(CustomParam param, String value) {
    if (param.type != 'json' && param.options.isNotEmpty) {
      // Keep the default fallback and any inherited alternate options intact;
      // OCR sends the first option for non-JSON custom parameters.
      param.options[0] = value;
    } else {
      param.defaultValue = value;
    }
  }

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

    if ((_enableTemperature && _temperatureNeedsRepair) ||
        (_enableTopP && _topPNeedsRepair)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.ocrSamplingSliderRepairRequired,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证参数名唯一且非空；缺少默认值时需有非空的有效选项，
    // 并校验请求实际使用的参数值。
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      // OCR requests use the first option for non-JSON parameters.
      final rawValue = param.type != 'json' && param.options.isNotEmpty
          ? param.options.first
          : param.defaultValue;
      final value = rawValue.trim();
      final hasRequiredValue =
          param.type == 'string' && param.options.isNotEmpty
              ? rawValue.isNotEmpty
              : value.isNotEmpty;
      final hasImplicitTrueBoolean = param.type == 'boolean' &&
          param.options.isEmpty &&
          param.defaultValue.trim().isEmpty;
      final hasStoredValue = param.defaultValue.trim().isNotEmpty ||
          param.options.any((option) => option.trim().isNotEmpty);
      final hasUnsupportedStoredType = hasStoredValue &&
          ParamType.values.every((type) => type.value != param.type);
      if (name == 'stream') {
        var isNonStreaming = false;
        if (param.type == 'boolean') {
          isNonStreaming = value.toLowerCase() == 'false';
        } else if (param.type == 'json') {
          try {
            isNonStreaming = jsonDecode(value) == false;
          } on FormatException {
            // The JSON validation below reports malformed values.
          }
        }
        if (!isNonStreaming) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.modelParamReserved(
                  '$name=true',
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
      if (const {
        'model',
        'messages',
        'temperature',
        'top_p',
        'max_tokens',
      }.contains(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.modelParamReserved(name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (name.isEmpty ||
          (!hasRequiredValue &&
              !hasImplicitTrueBoolean &&
              !hasUnsupportedStoredType)) {
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
      if (hasUnsupportedStoredType) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .ocrConfigUnsupportedParamSaveError(name, param.type),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (param.type == 'json') {
        try {
          jsonDecode(value);
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
      } else if (param.type == 'number' && value.isNotEmpty) {
        final number = num.tryParse(value);
        if (number == null || !number.isFinite) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.modelParamFinite(
                  name,
                  AppLocalizations.of(context)!.modelParamDefaultValue,
                  value,
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else if (param.type == 'boolean' &&
          value.isNotEmpty &&
          value.toLowerCase() != 'true' &&
          value.toLowerCase() != 'false') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .modelParamBooleanExpected(name, value),
            ),
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

    // Validate and serialize maxTokens only when enabled. A disabled field
    // retains its text, which may be stale or invalid.
    if (_enableMaxTokens) {
      final maxTokensStr = _maxTokensController.text.trim();
      if (maxTokensStr.isNotEmpty) {
        final maxTokens = int.tryParse(maxTokensStr);
        if (maxTokens == null || maxTokens <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.modelMaxTokensPositive,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        typeConfig['maxTokens'] = maxTokens;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.modelUnsavedMaxTokens),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
    }

    final requestSizeBudgetText = _requestSizeBudgetController.text.trim();
    if (requestSizeBudgetText.isNotEmpty) {
      final budgetBytes = ocrRequestSizeBudgetBytesFromMib(
        requestSizeBudgetText,
      );
      if (budgetBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.ocrJsonSizePositive),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }
      typeConfig['requestSizeBudgetBytes'] = budgetBytes;
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

            // 模型名称
            LabeledTextField(
              label: AppLocalizations.of(context)!.modelNameLabel,
              controller: _nameController,
              hintText: AppLocalizations.of(context)!.modelNameHint,
            ),
            const SizedBox(height: 16),

            // 模型 ID
            LabeledTextField(
              label: AppLocalizations.of(context)!.modelIdLabel,
              controller: _modelIdController,
              hintText: AppLocalizations.of(context)!.modelIdExample('gpt-4o'),
              required: true,
            ),
            const SizedBox(height: 24),

            // ==========================================================
            // OCR 参数设置（全部可选）
            // ==========================================================
            Text(
              AppLocalizations.of(context)!.ocrParamsTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.ocrParamsHelp,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 12),

            // Temperature
            LlmToggleSlider(
              label: AppLocalizations.of(context)!.modelTemperature,
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              enabled: _enableTemperature,
              onChanged: (v) => setState(() {
                _temperature = v;
                _temperatureNeedsRepair = false;
              }),
              onToggle: (v) => setState(() => _enableTemperature = v),
              description: AppLocalizations.of(context)!.modelTemperatureHelp,
            ),
            if (_temperatureNeedsRepair)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.of(context)!
                      .ocrSamplingTemperatureOutOfRange,
                  style: TextStyle(color: cs.error),
                ),
              ),

            // Top P
            LlmToggleSlider(
              label: 'Top P',
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              enabled: _enableTopP,
              onChanged: (v) => setState(() {
                _topP = v;
                _topPNeedsRepair = false;
              }),
              onToggle: (v) => setState(() => _enableTopP = v),
              description: AppLocalizations.of(context)!.llmTopPHelp,
            ),
            if (_topPNeedsRepair)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.of(context)!.ocrSamplingTopPOutOfRange,
                  style: TextStyle(color: cs.error),
                ),
              ),

            // Max Tokens
            LlmToggleTextField(
              label: AppLocalizations.of(context)!.assistantMaxTokens,
              controller: _maxTokensController,
              enabled: _enableMaxTokens,
              onToggle: (v) => setState(() => _enableMaxTokens = v),
              hintText: AppLocalizations.of(context)!.llmMaxTokensHint,
              keyboardType: TextInputType.number,
              description: AppLocalizations.of(context)!.llmTokensPerResponse,
            ),

            const SizedBox(height: 16),
            TextField(
              key: const Key('ocr_model_request_size_budget_mib'),
              controller: _requestSizeBudgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.ocrRequestSizeOverride,
                hintText: AppLocalizations.of(context)!.ocrInheritProvider,
                suffixText: 'MiB',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.providerRequestSizeBudgetBytes == null
                  ? AppLocalizations.of(context)!.ocrBudgetDefault
                  : AppLocalizations.of(context)!.ocrBudgetValue(
                      ocrRequestSizeBudgetMib(
                        widget.providerRequestSizeBudgetBytes!,
                      ).toString(),
                    ),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                final isUnsupportedType =
                    ParamType.values.every((type) => type.value != param.type);
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
                            // 类型选择
                            Container(
                              width: 110,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
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
                                  isExpanded: true,
                                  items: [
                                    if (isUnsupportedType)
                                      DropdownMenuItem(
                                        value: param.type,
                                        child: Text(
                                          param.type,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ...ParamType.values.map(
                                      (t) => DropdownMenuItem<String>(
                                        value: t.value,
                                        child: Text(
                                          localizedParamTypeLabel(
                                            AppLocalizations.of(context)!,
                                            t,
                                          ),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
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
                        if (isUnsupportedType)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                AppLocalizations.of(context)!
                                    .ocrConfigUnsupportedParamType(param.type),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey((
                                  i,
                                  param.type != 'json' &&
                                      param.options.isNotEmpty,
                                  _customParamValueFieldRevisions[i] ?? 0,
                                )),
                                initialValue: _effectiveCustomParamValue(param),
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
                                  hintText: localizedParamTypeDefaultValueHint(
                                      AppLocalizations.of(context)!,
                                      param.paramType),
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
                                  _setEffectiveCustomParamValue(param, v);
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
                                  initialValue:
                                      _effectiveCustomParamValue(param),
                                  hintText: localizedParamTypeDefaultValueHint(
                                      AppLocalizations.of(context)!,
                                      param.paramType),
                                  type: param.type,
                                  onSave: (result) {
                                    _setEffectiveCustomParamValue(
                                      param,
                                      result,
                                    );
                                    _customParamValueFieldRevisions[i] =
                                        (_customParamValueFieldRevisions[i] ??
                                                0) +
                                            1;
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
