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
  /// 幂等，保存前与 _hasUnsavedChanges 比较前调用。
  void _syncAdditionalOptionsFromBlocks() {
    for (final p in _reasoningParams) {
      if (p.isReasoningToggle || p.isEffortParam) continue;
      if (p.type == 'json' || p.type == 'boolean') continue;
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
  /// 模型配置中已存在同名参数，或内容被编辑过（与打开时快照不同）
  /// → 「当前：模型自定义」；否则「当前：供应商」。
  String _paramSourceLabel(ReasoningParam param) {
    final m = widget.model;
    final inModel = m?.reasoningParams.any(
          (p) =>
              p.paramName.trim().isNotEmpty &&
              p.paramName.trim() == param.paramName.trim(),
        ) ??
        false;
    final snapshot = _initialParamSnapshots[param];
    final edited = snapshot != null &&
        jsonEncode(param.toMap()) != jsonEncode(snapshot.toMap());
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
