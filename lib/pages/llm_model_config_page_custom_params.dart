part of 'llm_model_config_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _CustomParamsExt on _LlmModelConfigPageState {
  // ===================================================================
  // 自定义参数
  // ===================================================================

  void _addCustomParam() {
    setState(() {
      final param = CustomParam(paramName: '', defaultValue: '');
      _customParams.insert(0, param);
      // 注册勾选块状态（新参数：空勾选集合 + 空块列表）
      _customParamSelectedValues[param] = {};
      _customParamBlockValues[param] = [];
      _providerCustomParamValues[param] = [];
      // Shift existing error keys by +1 since a new param was inserted at 0
      final newErrors = <int, String?>{};
      for (final entry in _jsonErrors.entries) {
        newErrors[entry.key + 1] = entry.value;
      }
      _jsonErrors
        ..clear()
        ..addAll(newErrors);
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
      _jsonErrors.remove(index);
      // Shift indices after removal
      final newErrors = <int, String?>{};
      for (final entry in _jsonErrors.entries) {
        final newKey = entry.key > index ? entry.key - 1 : entry.key;
        newErrors[newKey] = entry.value;
      }
      _jsonErrors
        ..clear()
        ..addAll(newErrors);
    });
  }

  void _validateJsonField(int index, CustomParam param) {
    if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
      try {
        jsonDecode(param.defaultValue.trim());
        _jsonErrors.remove(index);
      } catch (e) {
        _jsonErrors[index] = formatJsonError(param.defaultValue.trim(), e);
      }
    } else {
      _jsonErrors.remove(index);
    }
  }

  bool _jsonParamHasError(int index) => _jsonErrors.containsKey(index);
}
