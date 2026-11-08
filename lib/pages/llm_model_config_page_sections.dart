part of 'llm_model_config_page.dart';

// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

/// 上下文长度常用备选值（点击输入框时弹出，也可直接输入）。
const List<String> kContextLengthSuggestions = [
  '1024',
  '2048',
  '4096',
  '8192',
  '65536',
  '131072',
  '262144',
  '1048576',
];

extension _BuildSectionsExt on _LlmModelConfigPageState {
  List<Widget> _buildBasicSettingsSection(ColorScheme cs) {
    return [
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
      const SizedBox(height: 16),

      // 上下文长度
      LabeledTextField(
        label: AppLocalizations.of(context)!.llmContextLength,
        controller: _contextController,
        hintText: AppLocalizations.of(context)!.llmContextHint,
        required: true,
        keyboardType: TextInputType.number,
        description: AppLocalizations.of(context)!.llmContextHelp,
        suggestions: kContextLengthSuggestions,
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildReasoningSection(ColorScheme cs) {
    // 外包 KeyedSubtree：reset 还原后重建整个推理区，让输入框
    // 显示还原后的值（TextFormField 的 internal state 不跟随
    // initialValue 更新）。
    return [
      KeyedSubtree(
        key: ValueKey('reasoning-section-$_reasoningResetVersion'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildReasoningSectionInner(cs),
        ),
      ),
    ];
  }

  List<Widget> _buildReasoningSectionInner(ColorScheme cs) {
    return [
      // ==========================================================
      // 推理参数（可开关，每个参数独立控制）
      // ==========================================================
      Text(
        AppLocalizations.of(context)!.llmReasoningParams,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        AppLocalizations.of(context)!.llmReasoningFullHelp,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),

      // 推理开关 — 始终在第一个位置
      _buildReasoningToggleSection(cs),

      // 推理力度 — 有且只有一个 card（通过「添加推理力度」按钮添加）
      _buildReasoningEffortSection(cs),

      // 附加推理参数（通过「添加推理参数」按钮添加，拖拽把手排序）
      if (_additionalReasoningParams.isNotEmpty)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _additionalReasoningParams.length,
          onReorderItem: _reorderAdditionalParam,
          itemBuilder: (context, i) {
            // 拖拽动画期间 framework 可能用临时索引请求构建，
            // 越界时返回空占位，避免重建过程中的越界崩溃
            final additional = _additionalReasoningParams;
            if (i >= additional.length) {
              return const SizedBox.shrink(key: ValueKey('rlv-placeholder'));
            }
            final param = additional[i];
            return KeyedSubtree(
              // ReorderableListView 要求每个 item 有 key；用实例身份
              // 保证拖拽动画期间 key 稳定
              key: ValueKey('add-param-${identityHashCode(param)}'),
              child: _buildAdditionalReasoningParamCard(param, i, cs),
            );
          },
        ),
      const SizedBox(height: 8),
      Center(
        child: TextButton.icon(
          icon: Icon(
            Icons.add,
            size: 16,
            color: null,
          ),
          label: Text(
            AppLocalizations.of(context)!.llmAddReasoningParam,
            style: TextStyle(
              fontSize: 13,
              color: null,
            ),
          ),
          onPressed: _addReasoningParam,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildLlmParamsSection(ColorScheme cs) {
    return [
      // ==========================================================
      // LLM 参数设置（带开关）
      // ==========================================================
      Text(
        AppLocalizations.of(context)!.providerLlmParams,
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

      // 端点类型覆盖（默认关 = 继承供应商）
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  AppLocalizations.of(context)!.llmCustomEndpointType,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.llmInheritEndpointType,
                ),
                value: _overrideEndpointType,
                onChanged: (v) => setState(() => _overrideEndpointType = v),
              ),
              if (_overrideEndpointType)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    initialValue: _apiProtocol,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!
                          .providerEndpointTypeLabel,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.hub_outlined, color: Colors.blue),
                    ),
                    items: supportedApiProtocolsForSupplier(
                      widget.provider?.apiProtocol ??
                          apiProtocolFromLegacyEndpointType(
                            widget.provider?.endpointType,
                          ),
                      connectorType: widget
                          .provider?.legacyFields['connectorType'] as String?,
                    )
                        .map(
                          (protocol) => DropdownMenuItem(
                            value: protocol,
                            child: Text(
                              apiProtocolLabels[protocol] ?? protocol,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _apiProtocol = v);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context)!.llmEndpointHelp,
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),

      // Temperature
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.modelTemperature,
        value: _temperature,
        min: 0.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableTemperature,
        onChanged: (v) => setState(() => _temperature = v),
        onToggle: (v) => setState(() => _enableTemperature = v),
        description: AppLocalizations.of(context)!.llmTemperatureHelp,
      ),

      // Top P
      LlmToggleSlider(
        label: 'Top P',
        value: _topP,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        enabled: _enableTopP,
        onChanged: (v) => setState(() => _topP = v),
        onToggle: (v) => setState(() => _enableTopP = v),
        description: AppLocalizations.of(context)!.llmTopPHelp,
      ),

      // Frequency Penalty
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.llmFrequencyPenaltyLabel,
        value: _frequencyPenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableFrequencyPenalty,
        onChanged: (v) => setState(() => _frequencyPenalty = v),
        onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
        description: AppLocalizations.of(context)!.llmFrequencyPenaltyHelp,
      ),

      // Presence Penalty
      LlmToggleSlider(
        label: AppLocalizations.of(context)!.llmPresencePenaltyLabel,
        value: _presencePenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enablePresencePenalty,
        onChanged: (v) => setState(() => _presencePenalty = v),
        onToggle: (v) => setState(() => _enablePresencePenalty = v),
        description: AppLocalizations.of(context)!.llmPresencePenaltyHelp,
      ),

      // Max Tokens
      LlmToggleTextField(
        label: AppLocalizations.of(context)!.providerMaxOutputTokensLabel,
        controller: _maxTokensController,
        enabled: _enableMaxTokens,
        onToggle: (v) => setState(() => _enableMaxTokens = v),
        hintText: AppLocalizations.of(context)!.llmMaxTokensHint,
        keyboardType: TextInputType.number,
        description: AppLocalizations.of(context)!.llmTokensPerResponse,
      ),

      // Seed
      LlmToggleTextField(
        label: AppLocalizations.of(context)!.llmSeedLabel,
        controller: _seedController,
        enabled: _enableSeed,
        onToggle: (v) => setState(() => _enableSeed = v),
        hintText: AppLocalizations.of(context)!.llmSeedHint,
        keyboardType: TextInputType.number,
        description: AppLocalizations.of(context)!.llmSeedHelp,
      ),

      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildCustomParamsSection() {
    final cs = Theme.of(context).colorScheme;
    return [
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
            label: Text(AppLocalizations.of(context)!.assistantAddParameter),
            onPressed: _addCustomParam,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        AppLocalizations.of(context)!.llmInheritedCustomHelp,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
              (_customParams.indexWhere((p) => p.paramName.trim() == name) !=
                      i ||
                  // 与推理参数重名（含继承自供应商的）同样拦截：
                  // 自定义参数会覆盖推理参数的值，聊天面板上的推理
                  // 开关会失效（与保存校验一致）。
                  _reasoningParams.any((p) => p.paramName.trim() == name));
          final hasInvalidName = name.isNotEmpty && !isValidParamName(name);
          return Card(
            key: ObjectKey(param),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            errorText: hasInvalidName
                                ? AppLocalizations.of(context)!
                                    .assistantParameterNameInvalid
                                : isDuplicate
                                    ? AppLocalizations.of(
                                        context,
                                      )!
                                        .modelParamDuplicate(
                                            param.paramName.trim())
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: StroomMenuStyle.surface(context),
                            borderRadius: StroomMenuStyle.borderRadius,
                            value: param.type,
                            isDense: true,
                            items: ParamType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.value,
                                    child: Text(
                                      localizedParamTypeLabel(
                                          AppLocalizations.of(context)!, t),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  param.type = v;
                                  param.typeDefaultOverridden = true;
                                  // 切换到 string/number：注册勾选块状态
                                  // 并清空 defaultValue（json 的旧值不应
                                  // 在 options 模式下继续发送）
                                  if (v == 'string' || v == 'number') {
                                    _customParamSelectedValues.putIfAbsent(
                                      param,
                                      () => param.options.toSet(),
                                    );
                                    _customParamBlockValues.putIfAbsent(
                                      param,
                                      () => List.of(param.options),
                                    );
                                    _providerCustomParamValues.putIfAbsent(
                                      param,
                                      () => const [],
                                    );
                                    param.defaultValue = '';
                                  }
                                  _validateJsonField(i, param);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 供应商传递下来的自定义参数不允许删除（只可修改
                      // 值/勾选）；模型自己添加的参数保留删除按钮。
                      if (!_isCustomParamInherited(param))
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _removeCustomParam(i),
                          tooltip:
                              AppLocalizations.of(context)!.modelParamDelete,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 点号参数名（如 provider.only）自动分行展示嵌套结构
                  ParamNamePathPreview(name: name),
                  // 值区按类型区分（与推理参数同款）：
                  // string/number → 选项值胶囊块（可添加多个、删除、
                  // 长按排序）；json → 默认参数值输入框；
                  // boolean → 无参数值（只有参数名）。
                  if (param.type == 'json')
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
                            inputFormatters: const [CodeSmartInputFormatter()],
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
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              errorText: _jsonErrors[i],
                              errorMaxLines: 3,
                              alignLabelWithHint: true,
                            ),
                            onChanged: (v) {
                              param.defaultValue = v;
                              param.typeDefaultOverridden = true;
                              _validateJsonField(i, param);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 20),
                          tooltip:
                              AppLocalizations.of(context)!.chatFullscreenEdit,
                          onPressed: () {
                            showJsonValueEditorDialog(
                              context,
                              initialValue: param.defaultValue,
                              hintText: localizedParamTypeDefaultValueHint(
                                  AppLocalizations.of(context)!,
                                  param.paramType),
                              type: param.type,
                              onSave: (result) {
                                param.defaultValue = result;
                                param.typeDefaultOverridden = true;
                                _validateJsonField(i, param);
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ],
                    )
                  else if (param.type == 'boolean')
                    Text(
                      AppLocalizations.of(context)!.llmBooleanParamHelp,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    _buildCustomParamOptionBlocks(param, cs),
                ],
              ),
            ),
          );
        }),
      const SizedBox(height: 32),
    ];
  }
}
