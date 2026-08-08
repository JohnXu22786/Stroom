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

  /// 将 [param] 在「继承自供应商」与「模型独立」之间切换。
  /// 供应商参数被用户编辑时调用：内容与供应商原值不一致 → 清除
  /// inheritedFromProvider 标记（保存时写入模型）；编辑后又还原成与
  /// 供应商原值完全一致 → 恢复标记（保持继承，不写入模型）。
  /// 避免「改了又改回去，却因模型规则（如力度参数必须有选项值）而
  /// 无法保存」的死局。原值按实例身份索引：只有打开页面时就是继承
  /// 状态的参数才允许回退，新建的参数不会被误标为继承。
  /// 调用方需在自身的 setState 中执行。
  void _claimReasoningParam(ReasoningParam param) {
    final original = _providerOriginals[param];
    if (original != null && _sameReasoningParamAsProvider(param, original)) {
      param.inheritedFromProvider = true;
      return;
    }
    if (param.inheritedFromProvider) {
      param.inheritedFromProvider = false;
    }
  }

  /// 与供应商原值比较（开关的空字符串与 null 视为等价，兼容旧数据）。
  bool _sameReasoningParamAsProvider(
      ReasoningParam param, ReasoningParam original) {
    Map<String, dynamic> normalized(ReasoningParam p) {
      final map = p.toMap();
      if (map['onValue'] == '') map.remove('onValue');
      if (map['offValue'] == '') map.remove('offValue');
      return map;
    }

    return normalized(param).toString() == normalized(original).toString();
  }

  /// 该参数名是否源自供应商（打开页面时的继承集合，含随后被认领的）。
  /// 供应商参数只能覆盖、不能删除：删除模型副本后参数会重新继承回来，
  /// 因此供应商来源的参数不显示「删除」按钮。
  bool _isProviderOriginated(ReasoningParam param) =>
      _providerInheritedNames.contains(param.paramName.trim());

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
