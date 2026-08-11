part of 'chat_service.dart';

/// Sentinel value used to mark a custom param that should be omitted from
/// the request body (e.g. because its JSON value failed to parse). Distinct
/// from null, which is a legitimate value to send for some params.
class _OmittedSentinel {
  const _OmittedSentinel();
}

/// Single shared instance of the sentinel (used by tests for type matching).
const _OmittedSentinel _kOmittedSentinelInstance = _OmittedSentinel();

extension _ChatServiceParamsExt on ChatService {
  /// Returns the effective temperature considering assistant overrides.
  /// Returns null when no temperature toggle is enabled (model or assistant).
  double? get _effectiveTemperature {
    // Assistant override takes priority when enabled
    if (_assistantSettings != null && _assistantSettings!.enableTemperature) {
      return _assistantSettings!.temperature;
    }
    // Model-level toggle check
    final typeConfig = _modelConfig?.typeConfig;
    final enableTemperature =
        typeConfig?['enableTemperature'] as bool? ?? false;
    if (enableTemperature) {
      final temperature = typeConfig?['temperature'];
      if (temperature is num) return temperature.toDouble();
    }
    // Neither toggle is on — return null so it's NOT sent in the request
    return null;
  }

  /// Returns the effective maxTokens considering assistant overrides.
  /// Returns null when no max_tokens toggle is enabled (model or assistant).
  int? get _effectiveMaxTokens {
    // Assistant override takes priority when enabled
    if (_assistantSettings != null && _assistantSettings!.enableMaxTokens) {
      return _assistantSettings!.maxTokens;
    }
    // Model-level toggle check
    final typeConfig = _modelConfig?.typeConfig;
    final enableMaxTokens = typeConfig?['enableMaxTokens'] as bool? ?? false;
    if (enableMaxTokens) {
      final value = (typeConfig!['maxTokens'] as num?)?.toInt() ??
          (typeConfig['context'] as num?)?.toInt();
      if (value != null) return value;
    }
    // Neither toggle is on — return null so it's NOT sent in the request
    return null;
  }

  /// Build extraParams map from typeConfig and customParams for the API call.
  /// Merges provider-level and model-level standard LLM params + [ProviderParam]s
  /// with assistant-level [CustomParameter]s.
  /// Rule: ALL enabled params from provider AND model are used.
  ///       If duplicate names, model's value wins.
  /// Assistant-level params take final precedence.
  /// Reasoning params: the reasoning toggle (provider + model) is always
  /// sent when filled (onValue/offValue per the reasoning switch); additional
  /// reasoning params from both layers are sent only when [reasoning] is true
  /// and a value was selected for them.
  ///
  /// Custom params with invalid JSON values are omitted from the result (and
  /// NOT sent as quoted strings). The omission is logged so the user can
  /// find the offending config in the model settings page.
  Map<String, dynamic> _buildExtraParams({
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
  }) {
    final result = <String, dynamic>{};

    // 1. Provider-level params first (defaults)
    // 配置值可能为 null（UI 保存路径的残留/损坏数据）：as num 强转
    // 会抛 TypeError 让整次请求失败，统一判空跳过。
    if (_providerConfig != null) {
      final pc = _providerConfig!.typeConfig;
      // Top P
      final topP = pc['topP'];
      if (topP is num) {
        result['top_p'] = topP.toDouble();
      }
      // Frequency penalty
      final frequencyPenalty = pc['frequencyPenalty'];
      if (frequencyPenalty is num) {
        result['frequency_penalty'] = frequencyPenalty.toDouble();
      }
      // Presence penalty
      final presencePenalty = pc['presencePenalty'];
      if (presencePenalty is num) {
        result['presence_penalty'] = presencePenalty.toDouble();
      }
      // Seed
      final seed = pc['seed'];
      if (seed is num) {
        result['seed'] = seed.toInt();
      }

      // Provider-level custom params
      for (final cp in _providerConfig!.customParams) {
        result[cp.paramName] = ChatService._coerceCustomParam(
            cp.paramName, cp.type, _customParamEffectiveValue(cp),
            source: 'provider');
      }

      // Provider-level reasoning params:
      // - The reasoning toggle (isReasoningToggle=true) is ALWAYS sent when
      //   filled, mirroring the model level below: onValue when reasoning
      //   is on, offValue when off. Sending the off value explicitly lets
      //   the API disable reasoning instead of leaving the toggle absent.
      // - Additional reasoning params are only sent when reasoning is ON
      //   and a value was selected for them AND the param is usable
      //   ([ReasoningParam.isUsable]): a name-only param (no options,
      //   non-boolean) has no selectable value in the panel — a map entry
      //   for it can only be stale, so it must not be sent (sending the
      //   param name itself would inject garbage into the request body).
      //   注意：供应商层的运行时开关以「已选值是否存在」为准（聊天面板
      //   切换通过写入/移除参数值生效，不修改共享的供应商配置对象），
      //   因此这里不检查 rp.enabled。
      ReasoningParam? providerToggleParam;
      final providerExtraParams = <ReasoningParam>[];
      for (final rp in _providerConfig!.reasoningParams) {
        if (rp.isReasoningToggle) {
          providerToggleParam = rp;
        } else {
          providerExtraParams.add(rp);
        }
      }

      if (providerToggleParam != null && providerToggleParam.isFilledToggle) {
        // boolean 类型开关没有开/关值（输入框隐藏）：空值按
        // 'true'/'false' 发送。
        final onValue = providerToggleParam.onValue;
        final offValue = providerToggleParam.offValue;
        final toggleValue = reasoning
            ? ((onValue?.trim().isNotEmpty ?? false) ? onValue! : 'true')
            : ((offValue?.trim().isNotEmpty ?? false) ? offValue! : 'false');
        ChatService._setReasoningParam(
          result,
          providerToggleParam,
          toggleValue,
          source: 'provider',
        );
      }

      if (reasoning) {
        // 模型有自己的力度参数时，供应商的力度参数被模型版本遮蔽
        // （合并视图与面板均不显示它）：跳过——陈旧值会注入请求且
        // UI 无法清除。
        final hasModelEffort =
            findEffortParam(_modelConfig!.reasoningParams) != null;
        for (final rp in providerExtraParams) {
          if (rp.paramName.trim().isEmpty) continue;
          if (hasModelEffort && rp.isEffortParam) continue;
          // 模型有同名参数时，合并视图以模型版本为准（模型参数在前，
          // 供应商同名参数被遮蔽）：由模型循环负责发送，这里跳过。
          if (_modelConfig!.reasoningParams
              .any((m) => m.paramName == rp.paramName)) {
            continue;
          }
          // 不可用参数（仅参数名、无选项值、非布尔）没有可选值，面板
          // 开关不可用；map 中即使残留旧值也不得发送（UI 无法再选择它）。
          if (!rp.isUsable) continue;
          final selectedValue = reasoningParamValues[rp.paramName];
          if (selectedValue != null && selectedValue.isNotEmpty) {
            ChatService._setReasoningParam(
              result,
              rp,
              selectedValue,
              source: 'provider',
            );
          }
        }
      }
    }

    // 2. Model-level params (override provider params on name collision)
    // 同 provider 层：null/非 num 值判空跳过，避免 TypeError 整请求失败。
    final tc = _modelConfig!.typeConfig;
    // Top P
    final mTopP = tc['topP'];
    if (mTopP is num) {
      result['top_p'] = mTopP.toDouble();
    }
    // Frequency penalty
    final mFrequencyPenalty = tc['frequencyPenalty'];
    if (mFrequencyPenalty is num) {
      result['frequency_penalty'] = mFrequencyPenalty.toDouble();
    }
    // Presence penalty
    final mPresencePenalty = tc['presencePenalty'];
    if (mPresencePenalty is num) {
      result['presence_penalty'] = mPresencePenalty.toDouble();
    }
    // Seed
    final mSeed = tc['seed'];
    if (mSeed is num) {
      result['seed'] = mSeed.toInt();
    }

    // Model-level custom params
    for (final cp in _modelConfig!.customParams) {
      result[cp.paramName] = ChatService._coerceCustomParam(
          cp.paramName, cp.type, _customParamEffectiveValue(cp),
          source: 'model');
    }

    // Model-level reasoning params:
    // - The reasoning toggle param (isReasoningToggle=true) controls the
    //   overall reasoning on/off: when reasoning=true send onValue,
    //   when reasoning=false send offValue.
    //   If the toggle fields are all empty, skip it entirely (no toggle configured).
    // - Additional reasoning params (isReasoningToggle=false) are only sent
    //   when reasoning is ON and the param's own enabled flag is set.
    //   They send the selected value from reasoningParamValues.
    // 位置在助手层之前：同名冲突时按「供应商 < 模型 < 助手」的层级规则，
    // 助手层自定义参数/设置拥有最终优先级（见下方注释）。
    ReasoningParam? toggleParam;
    final extraParams = <ReasoningParam>[];
    for (final rp in _modelConfig!.reasoningParams) {
      if (rp.isReasoningToggle) {
        toggleParam = rp;
      } else {
        extraParams.add(rp);
      }
    }

    // Only send reasoning toggle if it exists AND is filled (has a paramName)
    if (toggleParam != null && toggleParam.isFilledToggle) {
      // boolean 类型开关没有开/关值（输入框隐藏）：空值按
      // 'true'/'false' 发送。
      final onValue = toggleParam.onValue;
      final offValue = toggleParam.offValue;
      final toggleValue = reasoning
          ? ((onValue?.trim().isNotEmpty ?? false) ? onValue! : 'true')
          : ((offValue?.trim().isNotEmpty ?? false) ? offValue! : 'false');
      ChatService._setReasoningParam(
        result,
        toggleParam,
        toggleValue,
        source: 'model',
      );
    }

    // Additional reasoning params: only sent when global toggle is ON.
    // 运行时开关以「已选值是否存在」为准（聊天面板切换通过写入/移除
    // 参数值生效）：有已选值即发送，不再检查配置里的 enabled 标记——
    // 该标记只是新建参数的默认状态，面板激活后以已选值为准，且激活
    // 状态能跨重启保留（旧行为下重启后已激活参数会静默失效）。
    if (reasoning) {
      for (final rp in extraParams) {
        if (rp.paramName.trim().isEmpty) continue;
        // 不可用参数（仅参数名、无选项值、非布尔）没有可选值，面板
        // 开关不可用；map 中即使残留旧值也不得发送（UI 无法再选择它）。
        if (!rp.isUsable) continue;
        final selectedValue = reasoningParamValues[rp.paramName];
        if (selectedValue != null && selectedValue.isNotEmpty) {
          ChatService._setReasoningParam(
            result,
            rp,
            selectedValue,
            source: 'model',
          );
        }
      }
    }

    // Assistant-level custom params (override model-level on name collision)
    if (_assistantCustomParams != null) {
      for (final cp in _assistantCustomParams!) {
        result[cp.name] = ChatService._coerceAssistantCustomParam(cp);
      }
    }

    // Assistant-level settings override model params when enableXxx is true
    if (_assistantSettings != null) {
      final as = _assistantSettings!;
      if (as.enableTopP) {
        result['top_p'] = as.topP;
      }
      if (as.enableFrequencyPenalty) {
        result['frequency_penalty'] = as.frequencyPenalty;
      }
      if (as.enablePresencePenalty) {
        result['presence_penalty'] = as.presencePenalty;
      }
      if (as.enableSeed && as.seed != null) {
        result['seed'] = as.seed;
      }
    }

    return ChatService._stripOmitted(result);
  }

  /// 自定义参数的生效值：
  /// - json 类型始终用 defaultValue（大输入框/全屏编辑的内容）；
  /// - string/number 优先第一个选项，其次 defaultValue；
  /// - boolean 无参数值，默认发送 'true'（配置了即开启）。
  static String _customParamEffectiveValue(CustomParam cp) {
    if (cp.type == 'json') return cp.defaultValue;
    if (cp.options.isNotEmpty) return cp.options.first;
    if (cp.defaultValue.trim().isNotEmpty) return cp.defaultValue;
    if (cp.type == 'boolean') return 'true';
    return '';
  }
}
