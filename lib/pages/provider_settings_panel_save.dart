part of 'provider_settings_panel.dart';

extension _ProviderSettingsPanelSaveExt on _ProviderSettingsPanelState {
  bool _validate() {
    final name = _nameController.text.trim();
    final host = _hostController.text.trim();
    final key = _keyController.text.trim();

    if (name.isEmpty || host.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('供应商名称、API 地址 和 Key 均为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Validate custom params
    final seenNames = <String>{};
    for (final param in _customParams) {
      final pn = param.paramName.trim();
      final hasValue =
          param.options.isNotEmpty || param.defaultValue.trim().isNotEmpty;
      if (pn.isEmpty || !hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      if (!seenNames.add(pn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $pn'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      // JSON 类型的默认值必须是合法 JSON
      if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
        try {
          jsonDecode(param.defaultValue.trim());
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('参数 "$pn" 的默认值不是合法 JSON：${param.defaultValue}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
      }
    }

    // Validate reasoning params
    final toggleParam = _toggleReasoningParam;
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
      return false;
    }

    for (final param in _reasoningParams) {
      final error = param.validationError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数错误：$error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Duplicate name check
    for (final param in _reasoningParams) {
      final pn = param.paramName.trim();
      if (pn.isEmpty) continue;
      if (!seenNames.add(pn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推理参数与自定义参数存在重名: $pn'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Validate maxTokens：开关开启但未填写 = 无效死配置（与模型页
    // 校验一致——开关显示开启但请求侧永不发送，用户被误导）
    final maxTokensStr = _maxTokensController.text.trim();
    if (_enableMaxTokens && maxTokensStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已启用最大输出 Token 数但未填写数值'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    if (maxTokensStr.isNotEmpty) {
      final maxTokens = int.tryParse(maxTokensStr);
      if (maxTokens == null || maxTokens <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最大输出 Token 数必须为正整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // Validate seed
    final seedStr = _seedController.text.trim();
    if (seedStr.isNotEmpty) {
      if (int.tryParse(seedStr) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('随机种子必须为整数'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    return true;
  }

  ProviderConfigItem _buildConfig() {
    final typeConfig = <String, dynamic>{};

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

    typeConfig['enableTemperature'] = _enableTemperature;
    typeConfig['enableTopP'] = _enableTopP;
    typeConfig['enableFrequencyPenalty'] = _enableFrequencyPenalty;
    typeConfig['enablePresencePenalty'] = _enablePresencePenalty;
    typeConfig['enableMaxTokens'] = _enableMaxTokens;
    typeConfig['enableSeed'] = _enableSeed;

    final maxTokensStr = _maxTokensController.text.trim();
    if (maxTokensStr.isNotEmpty) {
      typeConfig['maxTokens'] = int.parse(maxTokensStr);
    }

    final seedStr = _seedController.text.trim();
    if (seedStr.isNotEmpty) {
      typeConfig['seed'] = int.tryParse(seedStr);
    }

    // ASR upload settings
    if (_isAsrType) {
      typeConfig['uploadMethod'] = _uploadMethod.name;
      typeConfig['maxFileSizeMb'] = _maxFileSizeMb;
      typeConfig['preprocessing'] = _preprocessing;
      typeConfig['chunking'] = _chunking;
      typeConfig['compression'] = _compression;
      typeConfig['fallbackMethod'] = _fallbackMethod;
    }

    return ProviderConfigItem(
      providerName: _nameController.text.trim(),
      host: _hostController.text.trim(),
      key: _keyController.text.trim(),
      models: widget.config.models.map((m) => m.copy()).toList(),
      typeConfig: typeConfig,
      customParams: _customParams.map((p) => p.copy()).toList(),
      reasoningParams: _reasoningParams.map((p) => p.copy()).toList(),
      endpointType: _endpointType,
    );
  }
}
