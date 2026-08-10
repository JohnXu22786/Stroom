part of 'llm_model_config_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ReasoningActionsExt on _LlmModelConfigPageState {
  // ===================================================================
  // 推理参数
  // ===================================================================

  void _addReasoningParam() {
    setState(() {
      _reasoningParams.add(
        ReasoningParam(
          paramName: '',
          enabled: false,
          isEffortParam: false,
          options: [],
        ),
      );
    });
  }

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
      final removed = _reasoningParams.removeAt(index);
      // 删除力度参数时同步清空勾选块状态（避免重新添加后残留旧块）
      if (removed.isEffortParam) {
        _effortBlockValues.clear();
        _effortSelectedValues.clear();
        _providerEffortValues.clear();
      }
      // 删除附加参数时清理其勾选块状态
      _additionalBlockValues.remove(removed);
      _additionalSelectedValues.remove(removed);
      _providerAdditionalValues.remove(removed);
    });
  }

  // ===================================================================
  // 推理力度参数「勾选块」操作
  // ===================================================================

  /// 点击块：勾选/取消勾选。
  void _toggleEffortBlock(String value) {
    setState(() {
      if (!_effortSelectedValues.remove(value)) {
        _effortSelectedValues.add(value);
      }
    });
  }

  /// 删除自定义值块（供应商来源的块只能取消勾选，不能删除）。
  void _removeEffortBlock(String value) {
    setState(() {
      _effortBlockValues.remove(value);
      _effortSelectedValues.remove(value);
    });
  }

  /// 长按拖拽排序块：把 [from] 值移到 [to] 值的位置。
  /// 排序即修改，直接影响保存顺序（进而影响推理面板中力度选项的
  /// 显示顺序与默认值）。
  void _moveBlockTo(String from, String to) {
    if (from == to) return;
    setState(() {
      final fromIndex = _effortBlockValues.indexOf(from);
      final toIndex = _effortBlockValues.indexOf(to);
      if (fromIndex < 0 || toIndex < 0) return;
      _effortBlockValues.removeAt(fromIndex);
      _effortBlockValues.insert(toIndex, from);
    });
  }

  /// 拖拽排序附加参数（在附加参数之间移动；开关与力度参数的位置
  /// 由类别决定，不参与排序）。
  void _reorderAdditionalParam(int oldIndex, int newIndex) {
    setState(() {
      final additional = _additionalReasoningParams;
      final param = additional.removeAt(oldIndex);
      additional.insert(newIndex, param);
      // 重建工作副本：开关/力度保持原顺序，附加参数按新顺序
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

  // ===================================================================
  // 附加推理参数「勾选块」操作
  // ===================================================================

  /// 点击附加参数块：勾选/取消勾选。
  void _toggleAdditionalBlock(ReasoningParam param, String value) {
    final selected = _additionalSelectedValues[param];
    if (selected == null) return;
    setState(() {
      if (!selected.remove(value)) {
        selected.add(value);
      }
    });
  }

  /// 添加附加参数值块（对话框输入，默认勾选，带删除按钮）。
  Future<void> _addAdditionalBlockWithDialog(ReasoningParam param) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加选项值'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如 low、medium、high',
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
      final blocks = _additionalBlockValues[param];
      final selected = _additionalSelectedValues[param];
      if (blocks == null || selected == null) return;
      if (!blocks.contains(value)) {
        blocks.add(value);
        selected.add(value);
      }
    });
  }

  /// 删除附加参数值块（供应商来源的块只能取消勾选，不能删除）。
  void _removeAdditionalBlock(ReasoningParam param, String value) {
    setState(() {
      _additionalBlockValues[param]?.remove(value);
      _additionalSelectedValues[param]?.remove(value);
    });
  }

  /// 长按拖拽排序附加参数块：把 [from] 移到 [to] 的位置。
  void _moveAdditionalBlockTo(ReasoningParam param, String from, String to) {
    if (from == to) return;
    setState(() {
      final blocks = _additionalBlockValues[param];
      if (blocks == null) return;
      final fromIndex = blocks.indexOf(from);
      final toIndex = blocks.indexOf(to);
      if (fromIndex < 0 || toIndex < 0) return;
      blocks.removeAt(fromIndex);
      blocks.insert(toIndex, from);
    });
  }

  /// 把附加参数勾选块同步到工作副本 options（勾选值按块顺序写入）。
  /// string/number 生效；json 用大输入框；boolean 无参数值（清空
  /// options，聊天面板提供开/关切换）。幂等，保存前与
  /// _hasUnsavedChanges 比较前调用。
  void _syncAdditionalOptionsFromBlocks() {
    for (final p in _reasoningParams) {
      if (p.isReasoningToggle || p.isEffortParam) continue;
      if (p.type == 'json') continue;
      if (p.type == 'boolean') {
        if (p.options.isNotEmpty) p.options.clear();
        continue;
      }
      final blocks = _additionalBlockValues[p];
      final selected = _additionalSelectedValues[p];
      if (blocks == null || selected == null) continue;
      final synced = blocks.where((v) => selected.contains(v)).toList();
      if (jsonEncode(p.options) != jsonEncode(synced)) {
        p.options
          ..clear()
          ..addAll(synced);
      }
    }
  }

  // ===================================================================
  // 自定义参数（CustomParam）选项值胶囊块操作
  // ===================================================================

  /// 点击自定义参数选项块：勾选/取消勾选（照搬模型页推理力度块交互）。
  void _toggleCustomParamOption(CustomParam param, String value) {
    final selected = _customParamSelectedValues[param];
    if (selected == null) return;
    setState(() {
      if (!selected.remove(value)) {
        selected.add(value);
      }
    });
  }

  /// 长按拖拽排序自定义参数选项：把 [from] 移到 [to] 的位置。
  void _moveCustomParamOptionTo(CustomParam param, String from, String to) {
    if (from == to) return;
    setState(() {
      final options = param.options;
      final fromIndex = options.indexOf(from);
      final toIndex = options.indexOf(to);
      if (fromIndex < 0 || toIndex < 0) return;
      options.removeAt(fromIndex);
      options.insert(toIndex, from);
    });
  }

  /// 添加自定义参数选项值（对话框输入）。
  Future<void> _addCustomParamOptionWithDialog(CustomParam param) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加选项值'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如 low、medium、high',
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
      if (!param.options.contains(value)) {
        param.options.add(value);
        // 新选项默认勾选（照搬力度块：添加即选中）
        _customParamSelectedValues[param]?.add(value);
      }
    });
  }

  /// 自定义参数选项值区：胶囊块（照搬模型页推理力度同款——点击
  /// 勾选高亮、长按拖拽排序、右上角删除；默认全选）。
  Widget _buildCustomParamOptionBlocks(CustomParam param, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '点击块选中/取消（选中的值将参与发送），长按块拖拽排序。',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in param.options)
              _buildCustomParamOptionBlock(param, value, cs),
          ],
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加选项', style: TextStyle(fontSize: 13)),
          onPressed: () => _addCustomParamOptionWithDialog(param),
        ),
      ],
    );
  }

  Widget _buildCustomParamOptionBlock(
    CustomParam param,
    String value,
    ColorScheme cs,
  ) {
    final selected =
        _customParamSelectedValues[param]?.contains(value) ?? false;
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

    final withDelete = Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                param.options.remove(value);
                _customParamSelectedValues[param]?.remove(value);
              });
            },
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
          _moveCustomParamOptionTo(param, details.data, value),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: value,
          delay: const Duration(milliseconds: 330),
          childWhenDragging: Opacity(opacity: 0.3, child: withDelete),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: withDelete),
          ),
          child: GestureDetector(
            onTap: () => _toggleCustomParamOption(param, value),
            child: withDelete,
          ),
        );
      },
    );
  }

  /// 把自定义参数勾选块同步到工作副本 options（勾选值按原顺序写入；
  /// 未勾选的选项不保存）。json 类型用默认值输入框；boolean 类型
  /// 无参数值（清空 options）。幂等，保存前与 _hasUnsavedChanges
  /// 比较前调用。
  void _syncCustomParamOptionsFromBlocks() {
    for (final p in _customParams) {
      if (p.type == 'json') continue;
      if (p.type == 'boolean') {
        if (p.options.isNotEmpty) p.options.clear();
        continue;
      }
      final selected = _customParamSelectedValues[p];
      if (selected == null) continue;
      final synced = p.options.where((v) => selected.contains(v)).toList();
      if (jsonEncode(p.options) != jsonEncode(synced)) {
        p.options
          ..clear()
          ..addAll(synced);
      }
    }
  }

  // ===================================================================
  // 推理参数帮助方法
  // ===================================================================

  /// 还原参数到打开页面时的初始状态（reset 按钮）。力度参数同时
  /// 还原勾选块状态。还原后重建整个推理区（版本号 +1），让输入框
  /// 显示还原后的值。
  void _resetReasoningParam(ReasoningParam param) {
    final snapshot = _initialParamSnapshots[param];
    if (snapshot == null) return;
    setState(() {
      param.paramName = snapshot.paramName;
      param.onValue = snapshot.onValue;
      param.offValue = snapshot.offValue;
      param.type = snapshot.type;
      param.enabled = snapshot.enabled;
      param.options
        ..clear()
        ..addAll(snapshot.options);
      if (param.isEffortParam) {
        _effortBlockValues = List.of(_initialBlockValues);
        _effortSelectedValues = {..._initialSelectedValues};
      } else if (!param.isReasoningToggle &&
          param.type != 'json' &&
          param.type != 'boolean') {
        // 附加参数：还原勾选块状态
        final providerOptions = _providerAdditionalValues[param];
        if (providerOptions != null) {
          _additionalBlockValues[param] = [
            ...snapshot.options,
            ...providerOptions.where((v) => !snapshot.options.contains(v)),
          ];
          _additionalSelectedValues[param] = snapshot.options.isNotEmpty
              ? snapshot.options.toSet()
              : {...providerOptions};
        }
      }
      _reasoningResetVersion++;
    });
  }

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

  /// 参数来源状态（参数名标签后的括号显示）：
  /// 模型配置中已存在同名参数，或内容被编辑过（与打开时快照不同），
  /// 或本会话新建的参数（无初始快照）→ 「当前：模型自定义」；
  /// 否则「当前：供应商」。
  String _paramSourceLabel(ReasoningParam param) {
    final snapshot = _initialParamSnapshots[param];
    if (snapshot == null) {
      // 本会话新建的参数（添加按钮创建，无初始快照）
      return '当前：模型自定义';
    }
    final m = widget.model;
    final inModel = m?.reasoningParams.any(
          (p) =>
              p.paramName.trim().isNotEmpty &&
              p.paramName.trim() == param.paramName.trim(),
        ) ??
        false;
    final edited = jsonEncode(param.toMap()) != jsonEncode(snapshot.toMap());
    return (inModel || edited) ? '当前：模型自定义' : '当前：供应商';
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
  /// 排除所有 isEffortParam 参数：即使模型与供应商各自定义了不同名称的
  /// 力度参数，供应商的旧力度参数也不应作为「附加参数」展示。
  List<ReasoningParam> get _additionalReasoningParams {
    final effort = _effortReasoningParam;
    return _reasoningParams
        .where((p) => !p.isReasoningToggle && !p.isEffortParam && p != effort)
        .toList();
  }

  bool get _isToggleComplete {
    final toggle = _toggleReasoningParam;
    if (toggle == null) return false;
    return toggle.paramName.trim().isNotEmpty &&
        (toggle.onValue != null && toggle.onValue!.trim().isNotEmpty) &&
        (toggle.offValue != null && toggle.offValue!.trim().isNotEmpty);
  }
}
