part of 'provider_settings_panel.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelReasoningExt on _ProviderSettingsPanelState {
  void _addReasoningParam({bool isToggle = false}) {
    setState(() {
      _reasoningParams.add(
        ReasoningParam(
          paramName: '',
          enabled: false,
          isReasoningToggle: isToggle,
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

  ReasoningParam? get _toggleReasoningParam => _reasoningParams
      .cast<ReasoningParam?>()
      .firstWhere((p) => p?.isReasoningToggle ?? false, orElse: () => null);

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
        '推理开关控制聊天页面中推理功能的开启和关闭。'
        '推理力度参数允许只填参数名而不添加选项值。',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      _buildReasoningToggleSection(cs),
      _buildInferenceIntensitySection(cs),
      const SizedBox(height: 12),
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
          onPressed:
              _toggleReasoningParam != null ? () => _addReasoningParam() : null,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildReasoningToggleSection(ColorScheme cs) {
    final toggle = _toggleReasoningParam;
    if (toggle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加推理开关', style: TextStyle(fontSize: 13)),
            onPressed: () => _addReasoningParam(isToggle: true),
          ),
        ),
      );
    }

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
              decoration: const InputDecoration(
                labelText: '参数名',
                hintText: '如 thinking.type、reasoning',
                border: OutlineInputBorder(),
                isDense: true,
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
                    decoration: const InputDecoration(
                      labelText: '开启时值',
                      hintText: '如 enabled、true',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: '关闭时值',
                      hintText: '如 disabled、false',
                      border: OutlineInputBorder(),
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

  Widget _buildInferenceIntensitySection(ColorScheme cs) {
    final hasToggle = _toggleReasoningParam != null;

    // Find existing inference intensity param (non-toggle)
    final intensityParams =
        _reasoningParams.where((p) => !p.isReasoningToggle).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '推理力度',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '推理力度参数支持只填参数名而不添加具体选项值'
          '${!hasToggle ? '（需先添加推理开关后才能配置）' : ''}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (intensityParams.isNotEmpty)
          ...List.generate(intensityParams.length, (i) {
            final param = intensityParams[i];
            final actualIndex = _reasoningParams.indexOf(param);
            return _buildIntensityParamCard(param, actualIndex, i, cs);
          }),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: Icon(
            Icons.add,
            size: 16,
            color: hasToggle ? null : Colors.grey,
          ),
          label: Text(
            '添加推理力度参数',
            style: TextStyle(
              fontSize: 13,
              color: hasToggle ? null : Colors.grey,
            ),
          ),
          onPressed: hasToggle
              ? () {
                  final newParam = ReasoningParam(
                    paramName: '',
                    isReasoningToggle: false,
                    enabled: true,
                    options: [],
                  );
                  setState(() {
                    _reasoningParams.add(newParam);
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildIntensityParamCard(
    ReasoningParam param,
    int actualIndex,
    int displayIndex,
    ColorScheme cs,
  ) {
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
                      hintText: '如 reasoning_effort',
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
            const SizedBox(height: 12),
            Text(
              '选项值（可选，仅填参数名时发送参数名本身）',
              style: TextStyle(
                fontSize: 12,
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
                          hintText: '如 low, medium, high',
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
}
