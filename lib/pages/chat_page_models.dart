part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageModelsExt on _ChatPageState {
  void _configureAdapter() {
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.configure(entriesState);
    _recalculateSelectedModelIndex();
    // configure 把适配器重置到第一个模型；立即按当前对话的记录/助手
    // 默认/列表第一个恢复真实选择，避免供应商配置变更时模型跳变。
    _restoreActiveConversationModel();
    if (mounted) setState(() {});
  }

  /// Recalculates [_selectedModelIndex] based on the adapter's currently
  /// selected model, mapped through the display order (saved drag-sort).
  void _recalculateSelectedModelIndex() {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final idx = models.indexWhere(
      (m) =>
          m.configIndex == _adapter.currentConfigIndex &&
          m.modelIndex == _adapter.currentModelIndex,
    );
    if (idx >= 0) {
      final selectedName = models[idx].displayName;
      // Map to display order index so the panel highlights the right model
      final displayNames = _getModelNames();
      final displayIdx = displayNames.indexOf(selectedName);
      _selectedModelIndex = displayIdx >= 0 ? displayIdx : 0;
    } else {
      _selectedModelIndex = 0;
    }
  }

  void _navigateToProviderConfig() {
    final entriesState = ref.read(providerEntriesProvider);
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry != null) {
      Navigator.of(context, rootNavigator: true)
          .push(
        MaterialPageRoute(
          builder: (_) => ProviderConfigPage(entryId: llmEntry.id),
        ),
      )
          .then((_) async {
        if (!mounted) return;
        // 供应商页面的模型列表可能与这里共享拖动排序（model_order），
        // 返回时必须先重新加载保存的顺序，再按新顺序重算选中索引。
        try {
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          setState(
            () => _savedModelOrder = prefs.getStringList('model_order'),
          );
        } catch (e) {
          debugPrint('_navigateToProviderConfig reload order failed: $e');
        }
        if (mounted) _configureAdapter();
      });
    }
  }

  /// Returns the list of model display names for the attachment panel,
  /// ordered according to the user's saved drag-sort order if available.
  List<String> _getModelNames() {
    final entriesState = ref.read(providerEntriesProvider);
    final names = _adapter
        .availableModels(entriesState)
        .map((m) => m.displayName)
        .toList();
    // Apply saved order: bring known names to the front in saved order,
    // then append any new names not yet in the saved order.
    return applySavedOrder(names, _savedModelOrder);
  }

  /// Called when model is selected from the attachment panel.
  /// Uses the model name from the display list to find the correct
  /// adapter model, so that drag-reordered indices still select the
  /// right model. Saves current model's settings and restores the
  /// new model's per-model settings.
  void _onModelSelected(int idx) {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final displayNames = _getModelNames();
    if (idx < 0 || idx >= displayNames.length) return;

    final selectedName = displayNames[idx];
    final modelIdx = models.indexWhere((m) => m.displayName == selectedName);
    if (modelIdx < 0) return;

    // Capture old model name BEFORE setState changes _selectedModelIndex
    final oldModelName = _getCurrentModelName();

    // Save current model's settings before switching, using captured name
    SharedPreferences.getInstance().then((prefs) {
      try {
        if (oldModelName.isNotEmpty) {
          final allSettings = _loadPerModelSettingsMap(prefs);
          allSettings[oldModelName] = {
            'reasoningEnabled': ref.read(reasoningEnabledProvider),
            'reasoningEffortEnabled': ref.read(reasoningEffortEnabledProvider),
            'reasoningEffort': ref.read(reasoningEffortProvider),
            'reasoningParamValues': ref.read(reasoningParamValuesProvider),
          };
          prefs.setString('per_model_chat_settings', jsonEncode(allSettings));
        }
      } catch (e) {
        debugPrint('_onModelSelectionChanged save settings failed: $e');
      }
    });

    final model = models[modelIdx];
    _adapter.selectModel(entriesState, model.configIndex, model.modelIndex);
    setState(() => _selectedModelIndex = idx);
    // Persist the choice for THIS conversation so the user's switch survives
    // re-entry, without affecting other conversations. 同时记录绝对身份
    // （模型ID + 供应商名）：显示名重命名后该记录仍能解析回同一模型。
    final convId = ref.read(activeConversationIdProvider);
    if (convId != null) {
      ref.read(conversationsProvider.notifier).updateLastUsedModel(
            convId,
            selectedName,
            modelId: model.modelId,
            providerName: model.providerName,
          );
    }
    // 不再写全局 selected_model_index（"上次使用"规则已移除）：无记录的
    // 对话回退到助手默认 / 列表第一个，而不是继承其它对话的旧选择。
    SharedPreferences.getInstance().then((prefs) {
      try {
        // Restore the new model's per-model settings
        _restorePerModelSettings(prefs, idx);
      } catch (e) {
        debugPrint('_onModelSelectionChanged save index failed: $e');
      }
    });
  }

  /// Called when models are reordered by drag-and-drop in the model panel.
  void _onModelsReordered(List<String> reordered) {
    setState(() => _savedModelOrder = reordered);
    SharedPreferences.getInstance().then((prefs) {
      try {
        prefs.setStringList('model_order', reordered);
      } catch (e) {
        debugPrint('_onModelsReordered failed: $e');
      }
    });
  }

  /// Restores the model selection for a conversation by its stored
  /// reference: absolute identity (modelId + providerName) first, display
  /// name as fallback (from [Conversation.lastUsedModelName] and friends).
  void _selectModelByName(
    String modelName, {
    String? modelId,
    String? providerName,
  }) {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final displayNames = _getModelNames();
    final resolved = resolveModelRef(
      models: models,
      modelId: modelId,
      providerName: providerName,
      displayName: modelName,
    );
    if (resolved == null) return;
    final displayIdx = displayNames.indexOf(resolved.displayName);
    if (displayIdx < 0) return;

    final model = resolved;
    _adapter.selectModel(entriesState, model.configIndex, model.modelIndex);
    setState(() => _selectedModelIndex = displayIdx);
    // Restore per-model settings for this model
    SharedPreferences.getInstance().then((prefs) {
      try {
        _restorePerModelSettings(prefs, displayIdx);
      } catch (e) {
        debugPrint('_selectModelByName restore settings failed: $e');
      }
    });
  }

  /// 选择列表中的第一个模型（显示顺序，尊重拖动排序）。
  /// 无任何记录可恢复时的兜底：助手默认缺失 → 列表第一个。
  void _selectFirstDisplayModel() {
    final displayNames = _getModelNames();
    if (displayNames.isEmpty) return;
    _selectModelByName(displayNames.first);
  }

  /// Returns the display name of the currently selected model.
  String _getCurrentModelName() {
    final names = _getModelNames();
    if (_selectedModelIndex >= 0 && _selectedModelIndex < names.length) {
      return names[_selectedModelIndex];
    }
    return '';
  }

  /// Saves the current reasoning/reasoning-effort/reasoning-param settings
  /// to SharedPreferences, keyed by the current model's display name.
  void _saveCurrentModelSettings(SharedPreferences prefs) {
    try {
      final modelName = _getCurrentModelName();
      if (modelName.isEmpty) return;

      // Load existing per-model settings map
      final allSettings = _loadPerModelSettingsMap(prefs);
      allSettings[modelName] = {
        'reasoningEnabled': ref.read(reasoningEnabledProvider),
        'reasoningEffortEnabled': ref.read(reasoningEffortEnabledProvider),
        'reasoningEffort': ref.read(reasoningEffortProvider),
        'reasoningParamValues': ref.read(reasoningParamValuesProvider),
      };
      prefs.setString('per_model_chat_settings', jsonEncode(allSettings));
    } catch (e) {
      debugPrint('_saveCurrentModelSettings failed: $e');
    }
  }

  /// Restores the saved model selection (adapter state + per-model settings)
  /// from SharedPreferences. Also restores drag-sort order.
  ///
  /// This is used both on initial page load and after [_configureAdapter]
  /// resets the adapter state (e.g. when [providerEntriesProvider] changes),
  /// ensuring the adapter and UI stay in sync with the persisted selection.
  ///
  /// 恢复优先级（用户规则，不再有全局"上次使用"索引）：
  /// 1. 对话自身的模型记录（用户在对话内的显式选择，或创建时播种的
  ///    助手默认模型）——按绝对身份（模型ID + 供应商名）解析，显示名
  ///    重命名后仍可解析；旧数据只有显示名时按显示名匹配。
  /// 2. 对话所属助手的默认模型（对话无记录时实时解析）。
  /// 3. 列表第一个模型（显示顺序，尊重拖动排序）。
  void _restoreSavedModelSelection(SharedPreferences prefs) {
    // Restore saved model order (drag-sort persistence) first,
    // so model names resolve correctly.
    final savedOrder = prefs.getStringList('model_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      setState(() {
        _savedModelOrder = savedOrder;
      });
    }

    _restoreActiveConversationModel();
  }

  /// 为当前活跃对话应用模型选择（不依赖 prefs，供多条恢复路径复用）：
  /// 对话记录 → 助手默认 → 列表第一个。
  void _restoreActiveConversationModel() {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final convId = ref.read(activeConversationIdProvider);
    final conv = convId != null
        ? ref
            .read(conversationsProvider)
            .where((c) => c.id == convId)
            .firstOrNull
        : null;

    // 1. Per-conversation model record (user choice or seeded assistant
    // default) — absolute identity first, display name as legacy fallback.
    final perConvName = perConversationModelToRestore(
      lastUsedModelName: conv?.lastUsedModelName,
      lastUsedModelId: conv?.lastUsedModelId,
      lastUsedProviderName: conv?.lastUsedProviderName,
      availableModels: models,
    );
    if (perConvName != null) {
      _selectModelByName(
        perConvName,
        modelId: conv?.lastUsedModelId,
        providerName: conv?.lastUsedProviderName,
      );
      return;
    }

    // 2. Assistant default model — conversation has no own record, so the
    // assistant's CURRENT default applies (rule: 没有专门设置 → 助手默认).
    if (conv?.assistantId != null) {
      final assistant = ref
          .read(assistantProvider)
          .where((a) => a.id == conv!.assistantId)
          .firstOrNull;
      if (assistant != null) {
        final assistantDefault = perConversationModelToRestore(
          lastUsedModelName: assistant.defaultModelName,
          lastUsedModelId: assistant.defaultModelId,
          lastUsedProviderName: assistant.defaultProviderName,
          availableModels: models,
        );
        if (assistantDefault != null) {
          _selectModelByName(
            assistantDefault,
            modelId: assistant.defaultModelId,
            providerName: assistant.defaultProviderName,
          );
          return;
        }
      }
    }

    // 3. First model in the display list (rule: 助手没有设置 → 列表第一个).
    _selectFirstDisplayModel();
  }

  /// Restores the reasoning/reasoning-effort/reasoning-param settings
  /// for the model at the given display [index].
  void _restorePerModelSettings(SharedPreferences prefs, int index) {
    final names = _getModelNames();
    if (index < 0 || index >= names.length) return;
    final modelName = names[index];

    final allSettings = _loadPerModelSettingsMap(prefs);
    final modelSettings = allSettings[modelName];
    if (modelSettings
        case {
          'reasoningEnabled': bool re,
          'reasoningEffort': String refEff,
          'reasoningParamValues': Map<String, dynamic> rpv,
        }) {
      ref.read(reasoningEnabledProvider.notifier).state = re;
      // Restore reasoning effort enabled state (with default false)
      final bool ree =
          modelSettings['reasoningEffortEnabled'] as bool? ?? false;
      ref.read(reasoningEffortEnabledProvider.notifier).state = ree;
      // Validate reasoningEffort against known values
      const validEfforts = {'low', 'medium', 'high'};
      ref.read(reasoningEffortProvider.notifier).state =
          validEfforts.contains(refEff) ? refEff : 'medium';
      // Cast from Map<String, dynamic> (jsonDecode result) to Map<String, String>
      ref.read(reasoningParamValuesProvider.notifier).state = rpv.map(
        (k, v) => MapEntry(k, v.toString()),
      );
    } else {
      // No saved settings for this model — use defaults
      ref.read(reasoningEnabledProvider.notifier).state = false;
      ref.read(reasoningEffortEnabledProvider.notifier).state = false;
      ref.read(reasoningEffortProvider.notifier).state = 'medium';
      ref.read(reasoningParamValuesProvider.notifier).state = {};
    }

    // Heal sessions where the effort toggle is on but no effort value was
    // ever written to the map (the panel previously only saved explicitly
    // tapped options). Without this, the reasoning chip keeps showing "推理"
    // after restart even though the effort section looks configured.
    // Symmetrically, a leftover effort value with the toggle off is pruned
    // so the request stops sending it.
    // NOTE: custom params are deliberately NOT auto-healed here — writing
    // defaults for them would silently start sending params the user never
    // engaged; the custom params panel writes values on switch interaction.
    // The heal looks up the effort param from the adapter's CURRENT model;
    // skip it when the adapter is not configured for the restored model
    // (its cached reasoning params would belong to a different model).
    final adapterModels = _adapter.availableModels(
      ref.read(providerEntriesProvider),
    );
    final adapterMatchesRestoredModel = adapterModels.any(
      (m) =>
          m.configIndex == _adapter.currentConfigIndex &&
          m.modelIndex == _adapter.currentModelIndex &&
          m.displayName == modelName,
    );
    final restoredValues = ref.read(reasoningParamValuesProvider);
    final normalized = adapterMatchesRestoredModel
        ? ensureEffortValue(
            _adapter.reasoningParams,
            restoredValues,
            effortEnabled: ref.read(reasoningEffortEnabledProvider),
          )
        : restoredValues;
    if (normalized != restoredValues) {
      ref.read(reasoningParamValuesProvider.notifier).state = normalized;
    }
    // 模型当前没有可用推理参数（开关未填满 / 无选项值 / 非布尔）时，
    // 残留的开启标记一并清除：否则每次重启都会重新持久化陈旧状态，
    // 且配置恢复选项后会「悄悄」重新生效（与面板灰色不可用一致）。
    // 以适配器当前模型为准（与 ensureEffortValue 相同的守卫条件）。
    if (adapterMatchesRestoredModel) {
      final currentParams = _adapter.reasoningParams;
      if (!currentParams.any((p) => p.isUsable) &&
          ref.read(reasoningEnabledProvider)) {
        ref.read(reasoningEnabledProvider.notifier).state = false;
      }
      final currentEffort = findEffortParam(currentParams);
      if (currentEffort != null &&
          !currentEffort.isUsable &&
          ref.read(reasoningEffortEnabledProvider)) {
        ref.read(reasoningEffortEnabledProvider.notifier).state = false;
      }
    }
  }

  /// Loads the per-model settings map from SharedPreferences.
  Map<String, dynamic> _loadPerModelSettingsMap(SharedPreferences prefs) {
    final json = prefs.getString('per_model_chat_settings');
    if (json != null && json.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(json) as Map);
      } catch (_) {}
    }
    return {};
  }

  /// Persists the current reasoning settings to the current model's slot.
  /// Called when reasoning toggle, effort, or param values change.
  void _persistCurrentReasoningSettings() {
    SharedPreferences.getInstance().then((prefs) {
      _saveCurrentModelSettings(prefs);
    });
  }

  /// Chat composer rendered below the chat list, in the Column flow.
  Widget _buildComposer({
    required String? activeId,
    required String currentDraftText,
    required List<Attachment> currentDraftAttachments,
  }) {
    return ChatComposerWidget(
      conversationId: activeId,
      initialDraftText: currentDraftText,
      initialDraftAttachments: currentDraftAttachments,
      onSend: _onMessageSend,
      onStop: _stopStreaming,
      onPreviewAttachment: _showAttachmentPreview,
      mcpTools: _adapter.getAllToolDefinitions(),
      enabledTools: ref.watch(enabledToolNamesProvider),
      onEnabledToolsChanged: (tools) {
        ref.read(enabledToolNamesProvider.notifier).state = tools;
        _saveEnabledToolsToConversation();
      },
      modelNames: _getModelNames(),
      selectedModelIndex: _selectedModelIndex,
      onModelSelected: _onModelSelected,
      onModelsReordered: _onModelsReordered,
      reasoningParams: _adapter.reasoningParams,
      editingMessageId: _editingMessageId,
      editingMessageText: _editingMessageText,
      editingMessageAttachments: _editingMessageAttachments,
      onEditSend: _handleEditSend,
      onEditCancel: _handleEditCancel,
      showEditWarningOnEntry: _showEditWarningOnEntry,
      editWarningArmCount: _editWarningArmCount,
    );
  }
}
