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

  // ===================================================================
  // 推理参数帮助方法
  // ===================================================================

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

      // 附加推理参数（通过「添加推理参数」按钮添加）
      if (_additionalReasoningParams.isNotEmpty)
        ...List.generate(_additionalReasoningParams.length, (i) {
          final param = _additionalReasoningParams[i];
          final actualIndex = _reasoningParams.indexOf(param);
          return _buildAdditionalReasoningParamCard(
            param,
            actualIndex,
            i,
            cs,
          );
        }),
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
            Text(
              '选项值（可选，仅填参数名时参数值由模型配置提供）',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(effort.options.length, (j) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: effort.options[j],
                        readOnly: !toggleComplete,
                        decoration: InputDecoration(
                          labelText: '选项 ${j + 1}',
                          hintText: toggleComplete
                              ? '如 low, medium, high'
                              : '请先填写推理开关',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          effort.options[j] = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (effort.options.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: toggleComplete
                            ? () => _removeOptionFromParam(
                                  _reasoningParams.indexOf(effort),
                                  j,
                                )
                            : null,
                        tooltip: '删除选项',
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('添加选项', style: TextStyle(fontSize: 13)),
              onPressed: toggleComplete
                  ? () => _addOptionToParam(_reasoningParams.indexOf(effort))
                  : null,
            ),
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
    int actualIndex,
    int displayIndex,
    ColorScheme cs,
  ) {
    final isDuplicate = _isReasoningParamNameDuplicate(param);
    return Card(
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
                _buildTypeDropdown(param, cs),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeReasoningParam(actualIndex),
                  tooltip: '删除参数',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '选项值',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '这些选项将按顺序显示在推理面板中供选择。启用/禁用开关在推理面板中操作。',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(param.options.length, (j) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: param.options[j],
                        decoration: InputDecoration(
                          labelText: '选项 ${j + 1}',
                          hintText: '如 low, enabled, true, max',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          param.options[j] = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (param.options.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _removeOptionFromParam(actualIndex, j),
                        tooltip: '删除选项',
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加选项', style: TextStyle(fontSize: 13)),
              onPressed: () => _addOptionToParam(actualIndex),
            ),
          ],
        ),
      ),
    );
  }
}
