part of 'llm_model_config_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ReasoningBuildersExt on _LlmModelConfigPageState {
  /// 供应商继承标记徽章：显示在继承参数的卡片标题旁。
  Widget _buildInheritedBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '来自供应商',
        style: TextStyle(fontSize: 10, color: cs.onTertiaryContainer),
      ),
    );
  }

  /// 继承参数卡片底部的提示文案。
  Widget _buildInheritedHint(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '此参数继承自供应商配置，修改后将变为本模型独立配置；'
        '删除需在供应商设置中操作。',
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// 判断 [param] 的当前参数名是否与「本模型其他已填写参数」或
  /// 自定义参数重名（除自身外）。继承自供应商的参数不参与重名判定——
  /// 与供应商参数同名即模型覆盖（override），是受支持的行为。
  bool _isReasoningParamNameDuplicate(ReasoningParam param) {
    final name = param.paramName.trim();
    if (name.isEmpty) return false;
    return _reasoningParams.any(
          (p) =>
              p != param &&
              !p.inheritedFromProvider &&
              p.paramName.trim() == name,
        ) ||
        _customParams.any((p) => p.paramName.trim() == name);
  }

  /// Builds the reasoning toggle card section.
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

    final isToggleDuplicate = _isReasoningParamNameDuplicate(toggle);
    final inherited = toggle.inheritedFromProvider;
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
                if (inherited) ...[
                  _buildInheritedBadge(cs),
                  const SizedBox(width: 4),
                ],
                // 参数值类型选择
                _buildTypeDropdown(toggle, cs),
                const SizedBox(width: 4),
                if (!_isProviderOriginated(toggle))
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
                errorText: isToggleDuplicate ? '已存在该参数' : null,
                errorStyle: const TextStyle(fontSize: 11),
              ),
              onChanged: (v) {
                toggle.paramName = v;
                _claimReasoningParam(toggle);
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
                _claimReasoningParam(toggle);
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
                _claimReasoningParam(toggle);
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
            if (inherited) _buildInheritedHint(cs),
          ],
        ),
      ),
    );
  }

  /// Builds the reasoning effort section. If an effort param exists, shows
  /// the effort card. Otherwise, shows the "添加推理力度" button, which is
  /// disabled (gray) when no toggle exists.
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
  /// exactly one effort param.
  Widget _buildReasoningEffortCard(ReasoningParam effort, ColorScheme cs) {
    final toggleComplete = _isToggleComplete;

    final isDuplicate = _isReasoningParamNameDuplicate(effort);
    final inherited = effort.inheritedFromProvider;

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
                if (inherited) ...[
                  _buildInheritedBadge(cs),
                  const SizedBox(width: 4),
                ],
                _buildTypeDropdown(effort, cs),
                const SizedBox(width: 4),
                if (!_isProviderOriginated(effort))
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
                _claimReasoningParam(effort);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Text(
              '选项值（模型必须添加至少一个选项值）',
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
                _claimReasoningParam(effort);
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
                            ? () {
                                _removeOptionFromParam(
                                  _reasoningParams.indexOf(effort),
                                  j,
                                );
                                _claimReasoningParam(effort);
                              }
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
                  ? () {
                      _addOptionToParam(_reasoningParams.indexOf(effort));
                      _claimReasoningParam(effort);
                    }
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
            if (inherited) _buildInheritedHint(cs),
          ],
        ),
      ),
    );
  }

  /// Builds a type dropdown for a reasoning param.
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
              _claimReasoningParam(param);
            }
          },
        ),
      ),
    );
  }

  /// Builds a card for an additional (non-toggle, non-effort) reasoning param.
  Widget _buildAdditionalReasoningParamCard(
    ReasoningParam param,
    int actualIndex,
    int displayIndex,
    ColorScheme cs,
  ) {
    final isDuplicate = _isReasoningParamNameDuplicate(param);
    final inherited = param.inheritedFromProvider;
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
                _claimReasoningParam(param);
                setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 4),
                if (inherited) ...[
                  _buildInheritedBadge(cs),
                  const SizedBox(width: 4),
                ],
                _buildTypeDropdown(param, cs),
                const SizedBox(width: 4),
                if (!_isProviderOriginated(param))
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
                _claimReasoningParam(param);
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
                        onPressed: () {
                          _removeOptionFromParam(actualIndex, j);
                          _claimReasoningParam(param);
                        },
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
              onPressed: () {
                _addOptionToParam(actualIndex);
                _claimReasoningParam(param);
              },
            ),
            if (inherited) _buildInheritedHint(cs),
          ],
        ),
      ),
    );
  }
}
