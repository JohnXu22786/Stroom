part of 'chat_composer_widget.dart';

extension _ChatComposerPanelsExt on ChatComposerWidgetState {
  // ═══════════════════════════════════════════════════════════════
  // Settings panels
  // ═══════════════════════════════════════════════════════════════

  void _showModelPanel() {
    showModelPanel(
      context: context,
      models: widget.modelNames,
      selectedModelIndex: widget.selectedModelIndex,
      onModelSelected: widget.onModelSelected,
      onModelsReordered: widget.onModelsReordered,
    );
  }

  void _showToolsPanel() {
    showToolsPanel(
      context: context,
      tools: widget.mcpTools,
      enabledTools: widget.enabledTools,
      onToolToggle: (toolName, enabled) {
        final current = Set<String>.from(widget.enabledTools);
        if (enabled) {
          current.add(toolName);
        } else {
          current.remove(toolName);
        }
        widget.onEnabledToolsChanged(current);
      },
    );
  }

  void _showReasoningPanel() {
    final reasoningEnabled = ref.read(reasoningEnabledProvider);
    final reasoningEffortEnabled = ref.read(reasoningEffortEnabledProvider);
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    final effortParam = findEffortParam(widget.reasoningParams);
    // 推理参数「可用」判定（与面板 hasParams 一致，见 ReasoningParam.isUsable）：
    // 已填写的开关参数、有选项值的参数、布尔类型参数。仅参数名
    // （无选项值、非布尔）不算。
    final hasUsableParams = widget.reasoningParams.any((p) => p.isUsable);
    // 力度参数不可用（仅参数名、无选项值、非布尔）时：开关既不可用，
    // 残留的已选值与开启标记也应一并清除——否则面板显示关闭但请求
    // 仍会发送该值（自愈：刷新持久化的 per-model 设置）。
    final effortUnusable = effortParam != null && !effortParam.isUsable;
    var panelParamValues = reasoningParamValues;
    if (effortUnusable &&
        ((reasoningParamValues[effortParam.paramName]?.isNotEmpty ?? false) ||
            reasoningEffortEnabled)) {
      panelParamValues = Map<String, String>.from(reasoningParamValues)
        ..remove(effortParam.paramName);
      ref.read(reasoningParamValuesProvider.notifier).state = panelParamValues;
      ref.read(reasoningEffortEnabledProvider.notifier).state = false;
    }
    // 无任何可用推理参数时，推理开关状态也无意义：一并关闭（与面板
    // 的灰色不可用开关一致，避免残留开启标记在参数恢复后悄悄生效）。
    if (!hasUsableParams && reasoningEnabled) {
      ref.read(reasoningEnabledProvider.notifier).state = false;
    }
    showReasoningPanel(
      context: context,
      reasoningEnabled: reasoningEnabled && hasUsableParams,
      reasoningEffortEnabled: effortUnusable ? false : reasoningEffortEnabled,
      reasoningParamSelections: panelParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningToggle: (value) {
        ref.read(reasoningEnabledProvider.notifier).state = value;
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool('reasoning_enabled', value),
        );
      },
      onReasoningEffortToggle: (value) {
        ref.read(reasoningEffortEnabledProvider.notifier).state = value;
        // Keep the effort value in sync with the toggle: enabling writes
        // the default option (so the chip shows the value and the request
        // sends it), disabling removes it (so it stops being sent).
        final current =
            Map<String, String>.from(ref.read(reasoningParamValuesProvider));
        if (value) {
          // 运行时开关以已选值为准：开启时写入默认选项。布尔类型无选项
          // 值，开关即值（写入 'true'，与自定义参数面板的布尔约定一致）。
          if (effortParam != null &&
              (current[effortParam.paramName]?.isNotEmpty ?? false) != true) {
            if (effortParam.options.isNotEmpty) {
              current[effortParam.paramName] = effortParam.options.first;
              ref.read(reasoningParamValuesProvider.notifier).state = current;
            } else if (effortParam.type == 'boolean') {
              current[effortParam.paramName] = 'true';
              ref.read(reasoningParamValuesProvider.notifier).state = current;
            }
          }
        } else {
          if (effortParam != null &&
              current.remove(effortParam.paramName) != null) {
            ref.read(reasoningParamValuesProvider.notifier).state = current;
          }
        }
        // Keep reasoningEffortProvider in sync with the map so the two
        // sources of truth can't diverge after an off→on cycle (requests
        // use the map; this string is persisted alongside it).
        if (value && effortParam != null) {
          final mapValue = current[effortParam.paramName];
          if (mapValue != null && mapValue.isNotEmpty) {
            ref.read(reasoningEffortProvider.notifier).state = mapValue;
          } else if (effortParam.enabled && effortParam.options.isNotEmpty) {
            ref.read(reasoningEffortProvider.notifier).state =
                effortParam.options.first;
          }
        }
        // Effort toggle state is auto-persisted via the ref.listen in
        // chat_page.dart's _persistCurrentReasoningSettings mechanism.
      },
      onReasoningParamChanged: (paramName, value) {
        final current = Map<String, String>.from(
          ref.read(reasoningParamValuesProvider),
        );
        current[paramName] = value;
        ref.read(reasoningParamValuesProvider.notifier).state = current;
        // Sync reasoningEffortProvider when an effort param changes
        // so the effort value is available for API calls (chat_page sends
        // it via ChatAdapter.sendStreamWithTools).
        if (effortParam != null && paramName == effortParam.paramName) {
          ref.read(reasoningEffortProvider.notifier).state = value;
        }
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('reasoning_params', current.toString()),
        );
      },
    );
  }

  void _showCustomParamsPanel() {
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    final reasoningEnabled = ref.read(reasoningEnabledProvider);
    showCustomReasoningParamsPanel(
      context: context,
      reasoningEnabled: reasoningEnabled,
      reasoningParamSelections: reasoningParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningParamChanged: (paramName, value) {
        final current = Map<String, String>.from(
          ref.read(reasoningParamValuesProvider),
        );
        current[paramName] = value;
        ref.read(reasoningParamValuesProvider.notifier).state = current;
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('reasoning_params', current.toString()),
        );
      },
      onCustomParamToggle: (param, enabled) {
        if (param.paramName.trim().isEmpty) return;
        final current = Map<String, String>.from(
          ref.read(reasoningParamValuesProvider),
        );
        if (enabled) {
          // Write the default option so the param is actually sent and the
          // chip reflects the enabled state (matches the panel's default
          // highlight of the first option). Write even when a (possibly
          // stale, pre-fix) value already exists — the provider change is
          // what triggers the chip rebuild; keep the existing selection.
          // boolean 类型参数无选项：开启即写入 'true'。
          if (param.options.isNotEmpty) {
            current.putIfAbsent(param.paramName, () => param.options.first);
            ref.read(reasoningParamValuesProvider.notifier).state = current;
          } else if (param.type == 'boolean') {
            current[param.paramName] = 'true';
            ref.read(reasoningParamValuesProvider.notifier).state = current;
          }
        } else {
          if (current.remove(param.paramName) != null) {
            ref.read(reasoningParamValuesProvider.notifier).state = current;
          }
        }
      },
    );
  }
}
