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
        '基本设置',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 12),

      // 模型名称
      LabeledTextField(
        label: '模型名称',
        controller: _nameController,
        hintText: '输入显示名称（可选）',
      ),
      const SizedBox(height: 16),

      // 模型 ID
      LabeledTextField(
        label: '模型 ID',
        controller: _modelIdController,
        hintText: '如 gpt-4o',
        required: true,
      ),
      const SizedBox(height: 16),

      // 上下文长度
      LabeledTextField(
        label: '上下文长度',
        controller: _contextController,
        hintText: '输入上下文长度',
        required: true,
        keyboardType: TextInputType.number,
        description: '模型的最大上下文窗口大小（token 数）',
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
        '推理参数',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '推理开关控制聊天页面中推理功能的开启和关闭，由您定义参数名和对应的开/关值。'
        '推理力度参数有且只有一个：点击块选中/取消值，拖动把手排序，'
        '选中的值将按此顺序显示在聊天推理面板中供选择。'
        '您还可以通过底部按钮添加额外的推理参数。'
        '参数名支持点号嵌套（如 thinking.type 会展开为 {"thinking": {"type": "..."}}）。'
        '供应商已配置的推理参数会直接显示在本页，'
        '每次打开都会同步供应商的最新值。参数与选项值均可拖拽排序。',
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
            color: _toggleReasoningParam != null ? null : Colors.grey,
          ),
          label: Text(
            '添加推理参数',
            style: TextStyle(
              fontSize: 13,
              color: _toggleReasoningParam != null ? null : Colors.grey,
            ),
          ),
          onPressed: _toggleReasoningParam != null ? _addReasoningParam : null,
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
        'LLM 参数',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '开启的参数将作为默认值发送到 API 请求中',
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
                title: const Text('自定义端点类型'),
                subtitle: const Text('关闭时使用供应商设置的端点类型'),
                value: _overrideEndpointType,
                onChanged: (v) => setState(() => _overrideEndpointType = v),
              ),
              if (_overrideEndpointType)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _endpointType,
                    decoration: const InputDecoration(
                      labelText: '端点类型',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.hub_outlined,
                        color: Colors.blue,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'openai',
                        child: Text('OpenAI 兼容 (Chat Completions)'),
                      ),
                      DropdownMenuItem(
                        value: 'anthropic',
                        child: Text('Anthropic 格式 (Messages API)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _endpointType = v);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '端点类型需与供应商的 API 地址匹配；'
        '切换端点类型后，本模型的新对话请求将使用新格式。',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),

      // Temperature
      LlmToggleSlider(
        label: '温度 (Temperature)',
        value: _temperature,
        min: 0.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableTemperature,
        onChanged: (v) => setState(() => _temperature = v),
        onToggle: (v) => setState(() => _enableTemperature = v),
        description: '控制输出的随机性，值越高越有创造性',
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
        description: '核采样参数，控制词汇选择的累积概率',
      ),

      // Frequency Penalty
      LlmToggleSlider(
        label: '频率惩罚 (Frequency Penalty)',
        value: _frequencyPenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enableFrequencyPenalty,
        onChanged: (v) => setState(() => _frequencyPenalty = v),
        onToggle: (v) => setState(() => _enableFrequencyPenalty = v),
        description: '减少重复词的频率，负值增加重复',
      ),

      // Presence Penalty
      LlmToggleSlider(
        label: '存在惩罚 (Presence Penalty)',
        value: _presencePenalty,
        min: -2.0,
        max: 2.0,
        divisions: 40,
        enabled: _enablePresencePenalty,
        onChanged: (v) => setState(() => _presencePenalty = v),
        onToggle: (v) => setState(() => _enablePresencePenalty = v),
        description: '鼓励讨论新话题，负值鼓励重复话题',
      ),

      // Max Tokens
      LlmToggleTextField(
        label: '最大输出 Token 数',
        controller: _maxTokensController,
        enabled: _enableMaxTokens,
        onToggle: (v) => setState(() => _enableMaxTokens = v),
        hintText: '可选，如 4096',
        keyboardType: TextInputType.number,
        description: '每次响应最多生成的 token 数',
      ),

      // Seed
      LlmToggleTextField(
        label: '随机种子 (Seed)',
        controller: _seedController,
        enabled: _enableSeed,
        onToggle: (v) => setState(() => _enableSeed = v),
        hintText: '可选，如 42',
        keyboardType: TextInputType.number,
        description: '设置后可使输出结果可复现',
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
          const Text(
            '自定义参数',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加参数'),
            onPressed: _addCustomParam,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '供应商已配置的自定义参数会直接显示在本页，'
        '每次打开都会同步供应商的最新值。',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 8),

      if (_customParams.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
          ),
        )
      else
        ...List.generate(_customParams.length, (i) {
          final param = _customParams[i];
          final name = param.paramName.trim();
          final isDuplicate = name.isNotEmpty &&
              (_customParams.indexWhere(
                        (p) => p.paramName.trim() == name,
                      ) !=
                      i ||
                  // 与推理参数重名（含继承自供应商的）同样拦截：
                  // 自定义参数会覆盖推理参数的值，聊天面板上的推理
                  // 开关会失效（与保存校验一致）。
                  _reasoningParams.any(
                    (p) => p.paramName.trim() == name,
                  ));
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
                            labelText: '参数名',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            errorText: isDuplicate ? '已存在该参数' : null,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: param.type,
                            isDense: true,
                            items: ParamType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.value,
                                    child: Text(
                                      t.label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  param.type = v;
                                  // 切换到 string/number：注册勾选块状态
                                  // 并清空 defaultValue（json 的旧值不应
                                  // 在 options 模式下继续发送）
                                  if (v == 'string' || v == 'number') {
                                    _customParamSelectedValues.putIfAbsent(
                                        param, () => param.options.toSet());
                                    _customParamBlockValues.putIfAbsent(
                                        param, () => List.of(param.options));
                                    _providerCustomParamValues.putIfAbsent(
                                        param, () => const []);
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
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _removeCustomParam(i),
                        tooltip: '删除参数',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 值区按类型区分（与推理参数同款）：
                  // string/number → 选项值胶囊块（可添加多个、删除、
                  // 长按排序）；json → 默认参数值输入框；
                  // boolean → 无参数值（只有参数名）。
                  if (param.type == 'json')
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: param.defaultValue,
                            decoration: InputDecoration(
                              labelText: '默认参数值',
                              hintText: param.paramType.defaultValueHint,
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
                              isDense: true,
                            ),
                            onChanged: (v) {
                              param.defaultValue = v;
                              _validateJsonField(i, param);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 20),
                          tooltip: '全屏编辑',
                          onPressed: () {
                            _showValueFullscreenEditor(
                              context,
                              param.defaultValue,
                              (result) {
                                param.defaultValue = result;
                                _validateJsonField(i, param);
                                setState(() {});
                              },
                              param.paramType.defaultValueHint,
                              type: param.type,
                            );
                          },
                        ),
                      ],
                    )
                  else if (param.type == 'boolean')
                    Text(
                      '布尔类型无需配置参数值。',
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
