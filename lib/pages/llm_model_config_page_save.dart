part of 'llm_model_config_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _SaveExt on _LlmModelConfigPageState {
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

    // 验证推理参数
    // Check 1: If there are any reasoning params, the toggle must exist and be filled
    final toggleParam = _reasoningParams.cast<ReasoningParam?>().firstWhere(
          (p) => p?.isReasoningToggle ?? false,
          orElse: () => null,
        );
    final hasNonToggleParams = _reasoningParams.any(
      (p) => !p.isReasoningToggle && p.paramName.trim().isNotEmpty,
    );

    if (hasNonToggleParams &&
        (toggleParam == null || !toggleParam.isFilledToggle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('推理开关必须先填写完整，其他推理参数才能生效'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check 2: For model-level inference intensity (non-toggle), if name is filled,
    // must have at least one option value
    for (int i = 0; i < _reasoningParams.length; i++) {
      final param = _reasoningParams[i];
      if (param.isReasoningToggle) continue;
      if (param.paramName.trim().isNotEmpty && param.options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('推理力度参数必须至少添加一个选项值'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Check 3: Validate each param individually
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

    // Check 4: Duplicate name check across all reasoning params
    final reasoningSeenNames = <String>{};
    for (int i = 0; i < _reasoningParams.length; i++) {
      final name = _reasoningParams[i].paramName.trim();
      if (name.isEmpty) {
        continue; // Empty names are caught by validationError above
      }
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

    // Check 4: Cross-check duplicate names between reasoning params and custom params
    for (final param in _reasoningParams) {
      final name = param.paramName.trim();
      if (name.isEmpty) continue;
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数与自定义参数存在重名: $name'),
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
    final typeConfig = <String, dynamic>{'context': contextValue};

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
      endpointType: _overrideEndpointType ? _endpointType : null,
    );

    Navigator.pop(context, result);
  }
}
