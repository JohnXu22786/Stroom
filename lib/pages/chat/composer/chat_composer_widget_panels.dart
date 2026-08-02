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
    showReasoningPanel(
      context: context,
      reasoningEnabled: reasoningEnabled,
      reasoningEffortEnabled: reasoningEffortEnabled,
      reasoningParamSelections: reasoningParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningToggle: (value) {
        ref.read(reasoningEnabledProvider.notifier).state = value;
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool('reasoning_enabled', value),
        );
      },
      onReasoningEffortToggle: (value) {
        ref.read(reasoningEffortEnabledProvider.notifier).state = value;
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
        final effortParam =
            widget.reasoningParams.cast<ReasoningParam?>().firstWhere(
                  (p) => p?.isEffortParam ?? false,
                  orElse: () => null,
                );
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
    );
  }
}
