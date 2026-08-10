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

  /// 拖拽排序把手（附加参数卡片与选项值行用；力度胶囊为长按拖拽，
  /// 无需把手）。
  Widget _buildDragHandle({required int index}) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
      ),
    );
  }

  /// 附加参数值块：与推理力度同款的胶囊块——点击勾选/取消（默认
  /// 全选），长按拖拽排序；供应商来源的块不可删除。
  Widget _buildAdditionalOptionBlock(
    ReasoningParam param,
    String value,
    ColorScheme cs,
  ) {
    final selected = _additionalSelectedValues[param]?.contains(value) ?? false;
    final fromProvider =
        _providerAdditionalValues[param]?.contains(value) ?? false;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );

    final pill = fromProvider
        ? chip
        : Stack(
            clipBehavior: Clip.none,
            children: [
              chip,
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeAdditionalBlock(param, value),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != value,
      onAcceptWithDetails: (details) =>
          _moveAdditionalBlockTo(param, details.data, value),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: value,
          // 长按触发时间（与力度胶囊一致，约 330ms）
          delay: const Duration(milliseconds: 330),
          childWhenDragging: Opacity(opacity: 0.3, child: pill),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: pill),
          ),
          child: GestureDetector(
            onTap: () => _toggleAdditionalBlock(param, value),
            child: pill,
          ),
        );
      },
    );
  }

  /// 推理力度值块：小圆形胶囊（点击高亮/取消，多选），横向排列，
  /// 长按胶囊拖拽排序。自定义（非供应商来源）块右上角带删除按钮。
  Widget _buildEffortOptionBlock(
    String value,
    ColorScheme cs, {
    required bool selected,
    required bool fromProvider,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // 配色与聊天推理面板的 OptionChip 一致：
        // 选中 = primaryContainer 淡底色 + 主色边框；未选 = 透明 + 灰边框
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );

    final pill = fromProvider
        ? chip
        : Stack(
            clipBehavior: Clip.none,
            children: [
              chip,
              // 自定义值删除按钮（右上角）
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeEffortBlock(value),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != value,
      onAcceptWithDetails: (details) => _moveBlockTo(details.data, value),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: value,
          // 长按触发时间（默认约 500ms，缩短至约 330ms 更跟手）
          delay: const Duration(milliseconds: 330),
          // 拖拽中半透明显示原位置
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: pill,
          ),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: pill),
          ),
          child: GestureDetector(
            onTap: () => _toggleEffortBlock(value),
            child: pill,
          ),
        );
      },
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
                // 还原此参数（重置为打开时的状态，含勾选块）
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: '还原此参数',
                  onPressed: () => _resetReasoningParam(effort),
                ),
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
                  effort.options
                    ..clear()
                    ..addAll(text.isNotEmpty ? [text] : []);
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
              // 勾选块：横向胶囊排列，长按拖拽排序
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in _effortBlockValues)
                    _buildEffortOptionBlock(
                      value,
                      cs,
                      selected: _effortSelectedValues.contains(value),
                      fromProvider: _providerEffortValues.contains(value),
                    ),
                ],
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
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
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
                  param.options
                    ..clear()
                    ..addAll(text.isNotEmpty ? [text] : []);
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
              // 勾选块：横向胶囊排列，长按拖拽排序（与推理力度同款）
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value
                      in _additionalBlockValues[param] ?? const <String>[])
                    _buildAdditionalOptionBlock(param, value, cs),
                ],
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
