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
          .then((_) {
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
    if (_savedModelOrder != null && _savedModelOrder!.isNotEmpty) {
      final ordered = <String>[];
      final remaining = Set<String>.from(names);
      for (final savedName in _savedModelOrder!) {
        if (remaining.remove(savedName)) {
          ordered.add(savedName);
        }
      }
      // Append any models not yet in the saved order
      ordered.addAll(remaining);
      return ordered;
    }
    return names;
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
    // re-entry (takes priority over the global saved index) without
    // affecting other conversations.
    final convId = ref.read(activeConversationIdProvider);
    var hadPerConversationModel = false;
    if (convId != null) {
      final conv = ref
          .read(conversationsProvider)
          .where((c) => c.id == convId)
          .firstOrNull;
      hadPerConversationModel = conv != null &&
          conv.lastUsedModelName != null &&
          conv.lastUsedModelName!.isNotEmpty;
      ref.read(conversationsProvider.notifier).updateLastUsedModel(
            convId,
            selectedName,
          );
    }
    SharedPreferences.getInstance().then((prefs) {
      try {
        // Only update the GLOBAL fallback when this conversation was not
        // overriding it with its own model — an override must not leak its
        // choice into other conversations that follow the global default.
        if (!hadPerConversationModel) {
          prefs.setInt('selected_model_index', idx);
        }
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

  /// Restores the model selection for a conversation by display name
  /// (from [Conversation.lastUsedModelName]).
  void _selectModelByName(String modelName) {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final displayNames = _getModelNames();
    final modelIdx = models.indexWhere((m) => m.displayName == modelName);
    if (modelIdx < 0) return;
    final displayIdx = displayNames.indexOf(modelName);
    if (displayIdx < 0) return;

    final model = models[modelIdx];
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

  /// Restores the saved model selection (index + adapter state + per-model
  /// settings) from SharedPreferences. Also restores drag-sort order.
  ///
  /// This is used both on initial page load and after [_configureAdapter]
  /// resets the adapter state (e.g. when [providerEntriesProvider] changes),
  /// ensuring the adapter and UI stay in sync with the persisted selection.
  ///
  /// IMPORTANT: The saved [selected_model_index] is a DISPLAY index (from the
  /// possibly-reordered model list shown to the user). We must map it through
  /// the model's display name to find the correct flat index in the adapter's
  /// [availableModels] list. Using the saved index directly on the flat list
  /// would select the wrong model when the display order differs from the flat
  /// order (e.g. after drag-and-drop reordering in the model panel).
  void _restoreSavedModelSelection(SharedPreferences prefs) {
    // Restore saved model order (drag-sort persistence) first,
    // so model names resolve correctly.
    final savedOrder = prefs.getStringList('model_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      setState(() {
        _savedModelOrder = savedOrder;
      });
    }

    // Per-conversation model takes priority over the global saved index:
    // the conversation's last used model (or its assistant default, seeded
    // at creation) was already restored by _selectModelByName during
    // message load. Applying the global index here would clobber it, so
    // re-apply the conversation's own choice (idempotent) and skip the
    // global restore entirely.
    final convId = ref.read(activeConversationIdProvider);
    final conv = convId != null
        ? ref
            .read(conversationsProvider)
            .where((c) => c.id == convId)
            .firstOrNull
        : null;
    final perConvName = perConversationModelToRestore(
      lastUsedModelName: conv?.lastUsedModelName,
      availableModels: _adapter.availableModels(
        ref.read(providerEntriesProvider),
      ),
    );
    if (perConvName != null) {
      _selectModelByName(perConvName);
      return;
    }

    // Restore saved model selection — clear stale index if out of range
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final saved = prefs.getInt('selected_model_index');
    int selectedIdx = 0;
    if (saved != null && saved >= 0) {
      // Map display index to flat index via display name:
      // The saved index is a DISPLAY index (from the user-facing reorderable
      // list). We need to find the corresponding model in the flat list by
      // resolving through the display name, not by using the index directly.
      final displayNames = _getModelNames();
      if (saved < displayNames.length) {
        selectedIdx = saved;
        final selectedName = displayNames[saved];
        final flatIdx = models.indexWhere(
          (m) => m.displayName == selectedName,
        );
        if (flatIdx >= 0) {
          final model = models[flatIdx];
          _adapter.selectModel(
            entriesState,
            model.configIndex,
            model.modelIndex,
          );
        } else {
          // Saved model not found in current list (e.g. deleted from
          // provider config). Fall back to the default (first model).
          selectedIdx = 0;
          prefs.remove('selected_model_index');
        }
      } else {
        // Saved index out of range for current display names — discard
        selectedIdx = 0;
        prefs.remove('selected_model_index');
      }
    } else {
      prefs.remove('selected_model_index');
    }
    setState(() => _selectedModelIndex = selectedIdx);

    // Restore per-model settings for the currently selected model
    _restorePerModelSettings(prefs, selectedIdx);
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
  }) {
    return ChatComposerWidget(
      conversationId: activeId,
      initialDraftText: currentDraftText,
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
      onFocusChanged: _onComposerFocusChanged,
      showEditWarningOnEntry: _showEditWarningOnEntry,
      editWarningArmCount: _editWarningArmCount,
    );
  }
}
