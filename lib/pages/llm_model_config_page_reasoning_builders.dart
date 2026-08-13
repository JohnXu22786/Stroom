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

  /// 拖拽排序把手（附加参数卡片用；力度/附加/自定义参数胶囊为长按
  /// 拖拽，无需把手）。
  Widget _buildDragHandle({required int index}) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
      ),
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
                // 还原此参数（重置为打开时的状态）
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: '还原此参数',
                  onPressed: () => _resetReasoningParam(toggle),
                ),
                // 推理开关是固定结构（不允许删除）：用启用开关替代删除
                // 按钮，控制该参数的 enabled 状态。
                Tooltip(
                  message: toggle.enabled ? '停用推理开关' : '启用推理开关',
                  child: Switch(
                    value: toggle.enabled,
                    onChanged: (v) => setState(() => toggle.enabled = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: toggle.paramName,
              decoration: InputDecoration(
                labelText: '参数名（${_paramSourceLabel(toggle)}）',
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
  /// The effort param itself is a fixed structure (有且只有一个) and is
  /// never deletable: a Switch (bound to [ReasoningParam.enabled]) takes
  /// the place of the delete button.
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
                // 还原此参数（重置为打开时的状态，含勾选块）
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: '还原此参数',
                  onPressed: () => _resetReasoningParam(effort),
                ),
                // 推理力度参数有且只有一个（不允许删除）：用启用开关
                // 替代删除按钮，控制该参数的 enabled 状态。
                Tooltip(
                  message: effort.enabled ? '停用推理力度' : '启用推理力度',
                  child: Switch(
                    value: effort.enabled,
                    onChanged: (v) => setState(() => effort.enabled = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: effort.paramName,
              readOnly: !toggleComplete,
              decoration: InputDecoration(
                labelText: '参数名（${_paramSourceLabel(effort)}）',
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
            // 参数值区按类型区分：
            // string/number → 勾选块（多选 + 长按排序）；
            // json → 大输入框（单个 JSON 值）；
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
                  // 赋值而非就地清空：sync 可能已把 options 替换为
                  // const []（boolean 类型切到 json 后），clear() 会抛
                  // UnsupportedError。
                  effort.options = text.isNotEmpty ? [text] : const [];
                  setState(() {});
                },
              )
            else ...[
              Text(
                '点击块选中/取消（选中的值将显示在聊天推理面板），'
                '长按块拖拽排序。供应商的值不可删除，取消勾选即可隐藏。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              // 勾选块：横向胶囊排列，长按拖拽排序。拖拽时其余块自动
              // 让位并显示目标槽位，松手后平滑滑入目标位置。
              DragSortArea(
                wrap: true,
                values: _effortBlockValues,
                selected: (v) => _effortSelectedValues.contains(v),
                deletable: (v) => !_providerEffortValues.contains(v),
                onTap: _toggleEffortBlock,
                onDelete: _removeEffortBlock,
                onReorder: _moveBlockTo,
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: Icon(Icons.add, size: 16),
                label: Text('添加值', style: TextStyle(fontSize: 13)),
                onPressed: toggleComplete ? _addEffortBlockWithDialog : null,
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
                _buildDragHandle(index: displayIndex),
                const SizedBox(width: 2),
                Expanded(
                  child: TextFormField(
                    initialValue: param.paramName,
                    decoration: InputDecoration(
                      labelText: '参数名（${_paramSourceLabel(param)}）',
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
                // 供应商传递下来的附加参数不允许删除（只可取消勾选/
                // 排序）；模型自己添加的参数保留删除按钮。
                if (!_isReasoningParamInherited(param))
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _removeReasoningParam(actualIndex),
                    tooltip: '删除参数',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 参数值区按类型区分：string/number → 勾选块（与推理力度
            // 相同的编辑样式，无「推理力度」标签）；json → 大输入框；
            // boolean → 无参数值（只有参数名）。
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
                  // 赋值而非就地清空：sync 可能已把 options 替换为
                  // const []（boolean 类型切到 json 后），clear() 会抛
                  // UnsupportedError。
                  param.options = text.isNotEmpty ? [text] : const [];
                  setState(() {});
                },
              )
            else ...[
              Text(
                '点击块选中/取消（选中的值将显示在聊天推理面板），'
                '长按块拖拽排序。供应商的值不可删除，取消勾选即可隐藏。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              // 勾选块：横向胶囊排列，长按拖拽排序（与推理力度同款，
              // 含目标槽位反馈与让位动画）
              DragSortArea(
                wrap: true,
                values: _additionalBlockValues[param] ?? const <String>[],
                selected: (v) =>
                    _additionalSelectedValues[param]?.contains(v) ?? false,
                deletable: (v) =>
                    !(_providerAdditionalValues[param]?.contains(v) ?? false),
                onTap: (v) => _toggleAdditionalBlock(param, v),
                onDelete: (v) => _removeAdditionalBlock(param, v),
                onReorder: (from, to) =>
                    _moveAdditionalBlockTo(param, from, to),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: Icon(Icons.add, size: 16),
                label: const Text('添加值', style: TextStyle(fontSize: 13)),
                onPressed: () => _addAdditionalBlockWithDialog(param),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
