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

  /// 上移/下移附加推理参数（仅在附加参数之间交换位置，跳过开关与
  /// 力度参数）。排序属于修改：涉及继承参数时将其认领为模型独立，
  /// 否则排序结果不会写入模型、下次打开即失效。
  /// 注意：此处直接清除继承标记并记入 [_forceClaimedParamsStore]（不走
  /// _claimReasoningParam 的内容比较回退）——toMap 不包含列表位置，
  /// 内容比较感知不到排序变化；强制认领后该参数本会话内不再回退。
  void _moveAdditionalReasoningParam(ReasoningParam param, int delta) {
    final additional = _additionalReasoningParams;
    final from = additional.indexOf(param);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= additional.length) return;
    setState(() {
      final target = additional[to];
      final i1 = _reasoningParams.indexOf(param);
      final i2 = _reasoningParams.indexOf(target);
      final list = _reasoningParams;
      final tmp = list[i1];
      list[i1] = list[i2];
      list[i2] = tmp;
      // 强制转为模型自有：排序结果才能随模型保存并跨打开保持
      param.inheritedFromProvider = false;
      target.inheritedFromProvider = false;
      _forceClaimedParamsStore.add(param);
      _forceClaimedParamsStore.add(target);
    });
  }

  /// 上移/下移 [paramIndex] 参数的选项值。排序属于修改：继承参数
  /// 会被认领为模型独立。
  void _moveOptionInParam(int paramIndex, int optionIndex, int delta) {
    final options = _reasoningParams[paramIndex].options;
    final to = optionIndex + delta;
    if (to < 0 || to >= options.length) return;
    setState(() {
      final tmp = options[optionIndex];
      options[optionIndex] = options[to];
      options[to] = tmp;
      _claimReasoningParam(_reasoningParams[paramIndex]);
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
  /// 被排序强制认领（[_forceClaimedParamsStore]）的参数不回退——排序结果
  /// 没有内容载体，不能因内容还原而丢失。
  /// 调用方需在自身的 setState 中执行。
  void _claimReasoningParam(ReasoningParam param) {
    if (!_forceClaimedParamsStore.contains(param)) {
      final original = _providerOriginals[param];
      if (original != null && _sameReasoningParamAsProvider(param, original)) {
        param.inheritedFromProvider = true;
        return;
      }
    }
    if (param.inheritedFromProvider) {
      param.inheritedFromProvider = false;
    }
  }

  /// 与供应商原值比较（开关的空字符串与 null 视为等价，兼容旧数据）。
  /// 注意：不能使用 toMap().toString() 直接比较——Dart 的 List/Map
  /// toString 不引用字符串，['']（已添加但未填写的空选项）会被打印成
  /// []，与「无选项」不可区分；jsonEncode 会正确区分 ["'"] 与 []。
  bool _sameReasoningParamAsProvider(
      ReasoningParam param, ReasoningParam original) {
    Map<String, dynamic> normalized(ReasoningParam p) {
      final map = p.toMap();
      if (map['onValue'] == '') map.remove('onValue');
      if (map['offValue'] == '') map.remove('offValue');
      return map;
    }

    return jsonEncode(normalized(param)) == jsonEncode(normalized(original));
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
