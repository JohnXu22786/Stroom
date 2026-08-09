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
    });
  }

  /// 在 [paramIndex] 参数中添加一个选项值（空字符串，待填写）。
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

  /// 拖拽排序块。排序即修改，直接影响保存顺序（进而影响推理面板
  /// 中力度选项的显示顺序与默认值）。
  /// [newIndex] 已由 ReorderableListView 调整（onReorderItem 语义）。
  void _reorderEffortBlock(int oldIndex, int newIndex) {
    setState(() {
      final value = _effortBlockValues.removeAt(oldIndex);
      _effortBlockValues.insert(newIndex, value);
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
