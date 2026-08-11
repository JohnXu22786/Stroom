part of 'provider_settings_panel.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelReasoningExt on _ProviderSettingsPanelState {
  // ===================================================================
  // 推理参数
  // ===================================================================

  /// 添加附加推理参数（非开关、非推理力度）。
  void _addReasoningParam() {
    setState(() {
      _reasoningParams.add(
        ReasoningParam(
          paramName: '',
          enabled: false,
          isReasoningToggle: false,
          isEffortParam: false,
          options: [],
        ),
      );
    });
  }

  /// 添加推理力度参数（有且只有一个）。
  void _addEffortReasoningParam() {
    setState(() {
      _reasoningParams.add(
        ReasoningParam(
          paramName: '',
          isReasoningToggle: false,
          isEffortParam: true,
          enabled: true,
          options: [],
        ),
      );
    });
  }

  void _removeReasoningParam(int index) {
    setState(() {
      _reasoningParams.removeAt(index);
    });
  }

  void _addOptionToParam(int paramIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.add('');
    });
  }

  void _removeOptionFromParam(int paramIndex, int optionIndex) {
    setState(() {
      _reasoningParams[paramIndex].options.removeAt(optionIndex);
    });
  }

  /// 拖拽排序附加推理参数（在附加参数之间移动；开关与力度参数的位置
  /// 由类别决定，不参与排序）。
  void _reorderAdditionalParam(int oldIndex, int newIndex) {
    setState(() {
      final additional = _additionalReasoningParams;
      final param = additional.removeAt(oldIndex);
      additional.insert(newIndex, param);
      // 重建列表：开关/力度保持原顺序，附加参数按新顺序
      final rebuilt = <ReasoningParam>[
        ..._reasoningParams
            .where((p) => p.isReasoningToggle || p.isEffortParam),
        ...additional,
      ];
      _reasoningParams
        ..clear()
        ..addAll(rebuilt);
    });
  }

  /// 拖拽排序 [paramIndex] 参数的选项值。
  void _reorderOptionInParam(int paramIndex, int oldIndex, int newIndex) {
    final options = _reasoningParams[paramIndex].options;
    setState(() {
      final value = options.removeAt(oldIndex);
      options.insert(newIndex, value);
    });
  }

  /// 拖拽排序把手。
  Widget _buildDragHandle({required int index}) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
      ),
    );
  }

  /// 选项值行（把手 + 输入框 + 删除按钮）。把手 = [DragSortRowHandle]：
  /// 长按把手拖拽整行排序（与胶囊的长按交互一致，拖拽时显示目标
  /// 槽位反馈与让位动画）。[feedback] 为拖拽时跟随手指的整行副本。
  Widget _buildOptionRow(
    int rowIndex,
    String value,
    ReasoningParam param,
    ColorScheme cs, {
    required bool editable,
  }) {
    final actualIndex = _reasoningParams.indexOf(param);
    final staticHandle = const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
    );
    final field = Expanded(
      // SyncedValueField：拖拽排序后行索引与值重新对应，外部值变化
      // 时同步显示文本（initialValue 不会跟随重建更新）
      child: SyncedValueField(
        value: value,
        readOnly: !editable,
        decoration: InputDecoration(
          labelText: '选项 ${rowIndex + 1}',
          hintText: editable ? '如 low, medium, high' : '请先填写推理开关',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          param.options[rowIndex] = v;
          setState(() {});
        },
      ),
    );
    final removeBtn = param.options.length > 1
        ? IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
            onPressed:
                editable ? () => _removeOptionFromParam(actualIndex, rowIndex) : null,
            tooltip: '删除选项',
          )
        : const SizedBox.shrink();
    // 拖拽反馈：整行副本（含静态把手图标）
    final row = SizedBox(
      height: 56,
      child: Row(
        children: [
          staticHandle,
          const SizedBox(width: 2),
          field,
          const SizedBox(width: 4),
          removeBtn,
        ],
      ),
    );
    return Row(
      children: [
        DragSortRowHandle(
          index: rowIndex,
          enabled: editable,
          feedback: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: row,
          ),
          child: staticHandle,
        ),
        const SizedBox(width: 2),
        field,
        const SizedBox(width: 4),
        removeBtn,
      ],
    );
  }

  // ===================================================================
  // 推理参数帮助方法
  // ===================================================================

  /// JSON 值格式校验（json 类型参数的大输入框用）。
  bool _jsonValueError(String value) {
    if (value.trim().isEmpty) return false;
    try {
      jsonDecode(value.trim());
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Returns the reasoning toggle param, or null if none exists.
  ReasoningParam? get _toggleReasoningParam => _reasoningParams
      .cast<ReasoningParam?>()
      .firstWhere((p) => p?.isReasoningToggle ?? false, orElse: () => null);

  /// Returns the reasoning effort param (one with isEffortParam=true), or null.
  ReasoningParam? get _effortReasoningParam => _reasoningParams
      .cast<ReasoningParam?>()
      .firstWhere((p) => p?.isEffortParam ?? false, orElse: () => null);

  /// Returns additional reasoning params (non-toggle, excluding the effort one).
  List<ReasoningParam> get _additionalReasoningParams {
    final effort = _effortReasoningParam;
    return _reasoningParams
        .where((p) => !p.isReasoningToggle && p != effort)
        .toList();
  }

  bool get _isToggleComplete {
    final toggle = _toggleReasoningParam;
    if (toggle == null) return false;
    // boolean 类型开关只需参数名（开/关值由聊天面板提供）
    if (toggle.type == 'boolean') {
      return toggle.paramName.trim().isNotEmpty;
    }
    return toggle.paramName.trim().isNotEmpty &&
        (toggle.onValue != null && toggle.onValue!.trim().isNotEmpty) &&
        (toggle.offValue != null && toggle.offValue!.trim().isNotEmpty);
  }

  /// 判断 [param] 的当前参数名是否与「本供应商其他已填写参数」或
  /// 自定义参数重名（除自身外）。
  bool _isReasoningParamNameDuplicate(ReasoningParam param) {
    final name = param.paramName.trim();
    if (name.isEmpty) return false;
    return _reasoningParams.indexWhere(
              (p) => p.paramName.trim() == name,
            ) !=
            _reasoningParams.indexOf(param) ||
        _customParams.any((p) => p.paramName.trim() == name);
  }

  List<Widget> _buildReasoningParamsSection(ColorScheme cs) {
    return [
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
        '推理力度参数有且只有一个，每个含参数名和可选项；参数名必填，'
        '选项值可选（仅填参数名时，参数值由模型配置提供——模型可在推理'
        '力度参数上添加自己的选项值）。'
        '您还可以通过底部按钮添加额外的推理参数。'
        '参数名支持点号嵌套（如 thinking.type 会展开为 {"thinking": {"type": "..."}}）。',
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

  /// Builds the reasoning toggle card section (mirrors the model config page).
  Widget _buildReasoningToggleSection(ColorScheme cs) {
    final toggle = _toggleReasoningParam;
    if (toggle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加推理开关', style: TextStyle(fontSize: 13)),
            onPressed: () {
              setState(() {
                _reasoningParams.insert(
                  0,
                  ReasoningParam(
                    paramName: '',
                    isReasoningToggle: true,
                    onValue: '',
                    offValue: '',
                    options: [],
                  ),
                );
              });
            },
          ),
        ),
      );
    }

    final isDuplicate = _isReasoningParamNameDuplicate(toggle);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.toggle_on_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '推理开关',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                // 参数值类型选择
                _buildTypeDropdown(toggle, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () =>
                      _removeReasoningParam(_reasoningParams.indexOf(toggle)),
                  tooltip: '删除推理开关',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: toggle.paramName,
              decoration: InputDecoration(
                labelText: '参数名',
                hintText: '如 thinking.type、reasoning',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: isDuplicate ? '已存在该参数' : null,
                errorStyle: const TextStyle(fontSize: 11),
              ),
              onChanged: (v) {
                toggle.paramName = v;
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            // 布尔类型开关与推理力度一致：无需配置开/关值，聊天面板
            // 提供开/关切换（请求按开关状态发送 'true'/'false'）。
            if (toggle.type == 'boolean')
              Text(
                '布尔类型无需配置参数值，聊天面板提供开/关切换。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: toggle.onValue ?? '',
                      decoration: InputDecoration(
                        labelText: '开启时值',
                        hintText: '如 enabled、true',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        toggle.onValue = v;
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: toggle.offValue ?? '',
                      decoration: InputDecoration(
                        labelText: '关闭时值',
                        hintText: '如 disabled、false',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        toggle.offValue = v;
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '推理开关打开时发送「${toggle.onValue ?? ''}」，'
                '关闭时发送「${toggle.offValue ?? ''}」',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the reasoning effort section (mirrors the model config page).
  /// If an effort param exists, shows the effort card. Otherwise, shows the
  /// "添加推理力度" button, which is disabled (gray) when no toggle exists.
  Widget _buildReasoningEffortSection(ColorScheme cs) {
    final effort = _effortReasoningParam;
    if (effort != null) {
      return _buildReasoningEffortCard(effort, cs);
    }
    // No effort param — show add button (always visible, disabled if no toggle)
    final hasToggle = _toggleReasoningParam != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton.icon(
          icon: Icon(
            Icons.add,
            size: 16,
            color: hasToggle ? null : Colors.grey,
          ),
          label: Text(
            '添加推理力度',
            style: TextStyle(
              fontSize: 13,
              color: hasToggle ? null : Colors.grey,
            ),
          ),
          onPressed: hasToggle ? _addEffortReasoningParam : null,
        ),
      ),
    );
  }

  /// Builds the reasoning effort card — a single card, same style as the
  /// toggle card. Only editable after the toggle is complete. There is
  /// exactly one effort param. Options are optional at the provider level:
  /// a name-only effort param defers its value to the model config /
  /// chat panel selection.
  Widget _buildReasoningEffortCard(ReasoningParam effort, ColorScheme cs) {
    final toggleComplete = _isToggleComplete;
    final isDuplicate = _isReasoningParamNameDuplicate(effort);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 18, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '推理力度',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                _buildTypeDropdown(effort, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () =>
                      _removeReasoningParam(_reasoningParams.indexOf(effort)),
                  tooltip: '删除推理力度参数',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: effort.paramName,
              readOnly: !toggleComplete,
              decoration: InputDecoration(
                labelText: '参数名',
                hintText: toggleComplete ? '如 reasoning_effort' : '请先填写推理开关',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: isDuplicate ? '已存在该参数' : null,
                errorStyle: const TextStyle(fontSize: 11),
              ),
              onChanged: (v) {
                effort.paramName = v;
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            // 参数值区按类型区分：string/number → 选项行；json → 大输入框；
            // boolean → 无参数值（只有参数名）。
            if (effort.type == 'boolean')
              Text(
                '布尔类型无需配置参数值，聊天面板提供开/关切换。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              )
            else if (effort.type == 'json')
              TextFormField(
                initialValue:
                    effort.options.isNotEmpty ? effort.options.first : '',
                readOnly: !toggleComplete,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'JSON 值',
                  hintText: '如 {"thinking": {"budget": 1024}}',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _jsonValueError(
                          effort.options.isNotEmpty ? effort.options.first : '')
                      ? 'JSON 格式不正确'
                      : null,
                  errorStyle: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) {
                  final text = v.trim();
                  effort.options
                    ..clear()
                    ..addAll(text.isNotEmpty ? [text] : []);
                  setState(() {});
                },
              )
            else ...[
              Text(
                '选项值（可选，仅填参数名时参数值由模型配置提供；'
                '长按把手拖拽排序）',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              // 选项值行（长按把手拖拽排序，含目标槽位反馈与让位动画）
              DragSortArea(
                wrap: false,
                values: effort.options,
                onReorder: (from, to) => _reorderOptionInParam(
                  _reasoningParams.indexOf(effort),
                  from,
                  to,
                ),
                itemBuilder: (context, j, value) => _buildOptionRow(
                  j,
                  value,
                  effort,
                  cs,
                  editable: toggleComplete,
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: Icon(Icons.add, size: 16),
                label: Text('添加选项', style: TextStyle(fontSize: 13)),
                onPressed: toggleComplete
                    ? () => _addOptionToParam(_reasoningParams.indexOf(effort))
                    : null,
              ),
            ],
            if (!toggleComplete)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '请先完整填写推理开关后再配置推理力度',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a type dropdown for a reasoning param (mirrors the model page).
  Widget _buildTypeDropdown(ReasoningParam param, ColorScheme cs) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ParamType.values.any((t) => t.value == param.type)
              ? param.type
              : 'string',
          isDense: true,
          items: ParamType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t.value,
                  child: Text(t.label, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => param.type = v);
            }
          },
        ),
      ),
    );
  }

  /// Builds a card for an additional (non-toggle, non-effort) reasoning param
  /// (mirrors the model config page).
  Widget _buildAdditionalReasoningParamCard(
    ReasoningParam param,
    int displayIndex,
    ColorScheme cs,
  ) {
    final isDuplicate = _isReasoningParamNameDuplicate(param);
    final actualIndex = _reasoningParams.indexOf(param);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 卡片间拖拽把手（附加参数排序）
                _buildDragHandle(index: displayIndex),
                const SizedBox(width: 2),
                Expanded(
                  child: TextFormField(
                    initialValue: param.paramName,
                    decoration: InputDecoration(
                      labelText: '参数名（支持点号嵌套）',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      hintText: '如 thinking.type 或 budget_tokens',
                      errorText: isDuplicate ? '已存在该参数' : null,
                      errorStyle: const TextStyle(fontSize: 11),
                    ),
                    onChanged: (v) {
                      param.paramName = v;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 尾部控件（类型/删除）用 Wrap 包裹，窄屏自动换行，
                // 避免 RenderFlex 溢出
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTypeDropdown(param, cs),
                    const SizedBox(width: 4),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _removeReasoningParam(actualIndex),
                      tooltip: '删除参数',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 参数值区按类型区分（照搬本面板推理力度的样式）：
            // string/number → 选项值文本行（可编辑、拖拽排序）；
            // json → 大输入框；boolean → 无参数值。
            if (param.type == 'boolean')
              Text(
                '布尔类型无需配置参数值。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              )
            else if (param.type == 'json')
              TextFormField(
                initialValue:
                    param.options.isNotEmpty ? param.options.first : '',
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'JSON 值',
                  hintText: '如 {"thinking": {"budget": 1024}}',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _jsonValueError(
                          param.options.isNotEmpty ? param.options.first : '')
                      ? 'JSON 格式不正确'
                      : null,
                  errorStyle: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) {
                  final text = v.trim();
                  param.options
                    ..clear()
                    ..addAll(text.isNotEmpty ? [text] : []);
                  setState(() {});
                },
              )
            else ...[
              Text(
                '选项值（长按把手拖拽排序）',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              // 选项值行（照搬推理力度行样式：把手 + 输入框 + 删除）
              DragSortArea(
                wrap: false,
                values: param.options,
                onReorder: (from, to) =>
                    _reorderOptionInParam(actualIndex, from, to),
                itemBuilder: (context, j, value) =>
                    _buildOptionRow(j, value, param, cs, editable: true),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加选项', style: TextStyle(fontSize: 13)),
                onPressed: () => _addOptionToParam(actualIndex),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
