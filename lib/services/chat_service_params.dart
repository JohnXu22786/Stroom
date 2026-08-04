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
  /// 合并一次请求的 usage 到累计（事件驱动：来自 AIStreamEvent.usage，
  /// per-request 隔离，不读共享 provider 槽）。
  ///
  /// [recordInput] 为 false 时只累计 cost，不累计 input/output tokens
  /// （压缩请求：其输入 ≈ 压缩前头部大小，不应作为"当前上下文大小"）。
  void _accumulateFromMap(Map<String, dynamic> usage,
      {bool recordInput = true}) {
    final acc = _accumulatedUsage ??= <String, dynamic>{};
    if (recordInput) {
      final input = usage['inputTokens'] as int?;
      if (input != null) {
        acc['inputTokens'] = (acc['inputTokens'] as int? ?? 0) + input;
      }
      final output = usage['outputTokens'] as int?;
      if (output != null) {
        acc['outputTokens'] = (acc['outputTokens'] as int? ?? 0) + output;
      }
    }
    final cost = usage['cost'] as double?;
    if (cost != null) {
      acc['cost'] = (acc['cost'] as double? ?? 0) + cost;
    }
  }

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
  /// When [reasoning] is true, also includes user-configured reasoning params
  /// from both provider and model configs (sent only when reasoning is enabled).
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
            cp.paramName, cp.type, cp.defaultValue,
            source: 'provider');
      }

      // Provider-level reasoning params (when reasoning enabled)
      if (reasoning) {
        ReasoningParam? toggleParam;
        final extraParams = <ReasoningParam>[];
        for (final rp in _providerConfig!.reasoningParams) {
          if (rp.isReasoningToggle) {
            toggleParam = rp;
          } else {
            extraParams.add(rp);
          }
        }

        // Reasoning toggle
        if (toggleParam != null && toggleParam.isFilledToggle) {
          final toggleValue = reasoning
              ? (toggleParam.onValue ?? 'true')
              : (toggleParam.offValue ?? 'false');
          ChatService._setReasoningParam(
            result,
            toggleParam,
            toggleValue,
            source: 'provider',
          );
        }

        // Additional reasoning params (inference intensity etc.)
        for (final rp in extraParams) {
          if (!rp.enabled) continue;
          if (rp.paramName.trim().isEmpty) continue;
          // If options are empty, send the param name itself as the value
          // (provider allows name-only inference intensity)
          if (rp.options.isEmpty) {
            setNestedParam(
              result,
              rp.paramName,
              rp.paramName,
            );
          } else {
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
          cp.paramName, cp.type, cp.defaultValue,
          source: 'model');
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

    // Reasoning params:
    // - The reasoning toggle param (isReasoningToggle=true) controls the
    //   overall reasoning on/off: when reasoning=true send onValue,
    //   when reasoning=false send offValue.
    //   If the toggle fields are all empty, skip it entirely (no toggle configured).
    // - Additional reasoning params (isReasoningToggle=false) are only sent
    //   when reasoning is ON and the param's own enabled flag is set.
    //   They send the selected value from reasoningParamValues.
    // Find the reasoning toggle (first one marked as toggle)
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
      final toggleValue = reasoning
          ? (toggleParam.onValue ?? 'true')
          : (toggleParam.offValue ?? 'false');
      ChatService._setReasoningParam(
        result,
        toggleParam,
        toggleValue,
        source: 'model',
      );
    }

    // Additional reasoning params: only sent when global toggle is ON
    if (reasoning) {
      for (final rp in extraParams) {
        if (!rp.enabled) continue;
        if (rp.paramName.trim().isEmpty) continue;
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

    return ChatService._stripOmitted(result);
  }
}
