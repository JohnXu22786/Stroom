part of 'llm_model_config_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without authorization warnings, but the receiver IS
// the State/StateNotifier, so runtime behavior is identical to the
// original inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ReasoningBuildersExt on _LlmModelConfigPageState {
  /// 判断 [param] 的当前参数名是否与「本模型其他已填写参数」或
  /// 自定义参数重名（除自身外）。
  bool _isReasoningParamNameDuplicate(ReasoningParam param) {
    final name = param.paramName.trim();
    if (name.isEmpty) return false;
    return _reasoningParams.any(
          (p) => p != param && p.paramName.trim() == name,
        ) ||
        _customParams.any((p) => p.paramName.trim() == name);
  }

  /// 推理力度值块（复用推理面板的 OptionChip 样式：点击高亮/取消，
  /// 多选）。块左侧为拖拽把手，自定义（非供应商来源）块右侧带删除。
  Widget _buildEffortOptionBlock(
    String value,
    int index,
    ColorScheme cs,
  ) {
    final selected = _effortSelectedValues.contains(value);
    final fromProvider = _providerEffortValues.contains(value);
    return Row(
      key: ValueKey('effort-block-$value'),
      children: [
        // 拖拽把手
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 2),
        // 勾选块（点击高亮/取消）
        Expanded(
          child: OptionChip(
            label: value,
            selected: selected,
            onTap: () => _toggleEffortBlock(value),
          ),
        ),
        if (!fromProvider)
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
            onPressed: () => _removeEffortBlock(value),
            tooltip: '删除该值',
          ),
      ],
    );
  }

  /// 添加力度值：弹出输入框，输入后作为勾选块出现（默认选中）。
  Future<void> _addEffortBlockWithDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加推理力度值'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如 max、ultra、deep',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    setState(() {
      if (!_effortBlockValues.contains(value)) {
        _effortBlockValues.add(value);
        _effortSelectedValues.add(value);
      }
    });
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
                errorText: isToggleDuplicate ? '已存在该参数' : null,
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

  /// Builds the reasoning effort section. If an effort param exists, shows
  /// the effort card with selectable/draggable option blocks. Otherwise,
  /// shows the "添加推理力度" button, disabled when no toggle exists.
  Widget _buildReasoningEffortSection(ColorScheme cs) {
    final effort = _effortReasoningParam;
    if (effort != null) {
      return _buildReasoningEffortCard(effort, cs);
    }
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

  /// Builds the reasoning effort card — a single card showing the param
  /// name and its option values as selectable blocks (multi-select, like
  /// the reasoning panel's OptionChip) that can be reordered by dragging
  /// the handle. Provider-provided values cannot be deleted (unchecking
  /// hides them); model-added values show a delete button.
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
              '点击块选中/取消（选中的值将显示在聊天推理面板），'
              '拖动把手排序。供应商的值不可删除，取消勾选即可隐藏。',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            // 勾选块列表（可拖拽排序）
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _effortBlockValues.length,
              onReorderItem: _reorderEffortBlock,
              itemBuilder: (context, index) {
                final value = _effortBlockValues[index];
                return _buildEffortOptionBlock(value, index, cs);
              },
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('添加值', style: TextStyle(fontSize: 13)),
              onPressed: toggleComplete ? _addEffortBlockWithDialog : null,
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
            }
          },
        ),
      ),
    );
  }

  /// Builds a card for an additional (non-toggle, non-effort) reasoning
  /// param. The card can be reordered among additional params by dragging
  /// its header handle; its option values are draggable rows.
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
                ReorderableDragStartListener(
                  index: displayIndex,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child:
                        Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                  ),
                ),
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
              '这些选项将按顺序显示在推理面板中供选择，拖动把手排序。'
              '启用/禁用开关在推理面板中操作。',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            // 选项值行（可拖拽排序）
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: param.options.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final value = param.options.removeAt(oldIndex);
                  param.options.insert(newIndex, value);
                });
              },
              itemBuilder: (context, j) {
                return Row(
                  key: ValueKey('opt-$actualIndex-$j'),
                  children: [
                    ReorderableDragStartListener(
                      index: j,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.drag_handle,
                            size: 20, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 2),
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
                        onPressed: () {
                          _removeOptionFromParam(actualIndex, j);
                        },
                        tooltip: '删除选项',
                      ),
                  ],
                );
              },
            ),
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
