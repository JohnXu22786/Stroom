part of 'provider_settings_panel.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelCustomParamsExt on _ProviderSettingsPanelState {
  /// 自定义参数选项值区（照搬本面板推理力度的行式样式）：
  /// 多值文本行 + 长按把手排序 + 删除 + 添加选项。
  Widget _buildProviderCustomParamOptionRows(
      CustomParam param, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选项值（长按把手拖拽排序）',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        DragSortArea(
          wrap: false,
          values: param.options,
          onReorder: (from, to) {
            setState(() {
              final value = param.options.removeAt(from);
              param.options.insert(to, value);
            });
          },
          itemBuilder: (context, j, value) {
            final staticHandle = const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
            );
            final field = Expanded(
              // SyncedValueField：拖拽排序后同步显示文本
              child: SyncedValueField(
                value: value,
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
            );
            final removeBtn = param.options.length > 1
                ? IconButton(
                    icon: const Icon(
                      Icons.remove_circle,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        param.options.removeAt(j);
                      });
                    },
                    tooltip: '删除选项',
                  )
                : const SizedBox.shrink();
            final row = SizedBox(
              height: 56,
              child: Row(
                children: [
                  staticHandle,
                  const SizedBox(width: 2),
                  field,
                  const SizedBox(width: 4),
                  removeBtn,
                ],
              ),
            );
            return Row(
              children: [
                DragSortRowHandle(
                  index: j,
                  feedback: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(8),
                    child: row,
                  ),
                  child: staticHandle,
                ),
                const SizedBox(width: 2),
                field,
                const SizedBox(width: 4),
                removeBtn,
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加选项', style: TextStyle(fontSize: 13)),
          onPressed: () {
            setState(() {
              param.options.add('');
            });
          },
        ),
      ],
    );
  }

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
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
    final error = validateJsonValue(param.type, param.defaultValue);
    if (error != null) {
      _jsonErrors[index] = error;
    } else {
      _jsonErrors.remove(index);
    }
  }

  bool _jsonParamHasError(int index) => _jsonErrors.containsKey(index);

  List<Widget> _buildCustomParamsSection(ColorScheme cs) {
    return [
      Row(
        children: [
          const Text(
            '自定义参数',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加参数'),
            onPressed: _addCustomParam,
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_customParams.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('暂无自定义参数', style: TextStyle(color: Colors.grey)),
          ),
        )
      else
        ...List.generate(_customParams.length, (i) {
          final param = _customParams[i];
          final name = param.paramName.trim();
          final isDuplicate = name.isNotEmpty &&
              (_customParams.indexWhere(
                    (p) => p.paramName.trim() == name,
                  ) !=
                  i);
          final hasInvalidName = name.isNotEmpty && !isValidParamName(name);
          return Card(
            key: ObjectKey(param),
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
                            labelText: '参数名',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            errorText: hasInvalidName
                                ? '参数名格式不正确（点号分段不能为空）'
                                : isDuplicate
                                    ? '已存在该参数'
                                    : null,
                            errorStyle: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (v) {
                            param.paramName = v;
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 110,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: param.type,
                            isDense: true,
                            items: ParamType.values
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.value,
                                    child: Text(
                                      t.label,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  param.type = v;
                                  // 切换到 string/number：清空 defaultValue
                                  // （json 的旧值不应在 options 模式下继续发送）
                                  if (v == 'string' || v == 'number') {
                                    param.defaultValue = '';
                                  }
                                  _validateJsonField(i, param);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _removeCustomParam(i),
                        tooltip: '删除参数',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 点号参数名（如 provider.only）自动分行展示嵌套结构
                  ParamNamePathPreview(name: name),
                  // 值区按类型区分（照搬本面板推理力度的处理）：
                  // string/number → 选项值文本行（多值、可编辑、把手排序）；
                  // json → 默认参数值输入框；boolean → 无参数值。
                  if (param.type == 'json')
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: param.defaultValue,
                            minLines: 4,
                            maxLines: 8,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            inputFormatters: const [
                              CodeSmartInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: '默认参数值',
                              hintText: param.paramType.defaultValueHint,
                              border: const OutlineInputBorder(),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _jsonParamHasError(i)
                                      ? Colors.red
                                      : Colors.grey.shade400,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              errorText: _jsonErrors[i],
                              errorMaxLines: 3,
                              alignLabelWithHint: true,
                            ),
                            onChanged: (v) {
                              param.defaultValue = v;
                              _validateJsonField(i, param);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 20),
                          tooltip: '全屏编辑',
                          onPressed: () {
                            showJsonValueEditorDialog(
                              context,
                              initialValue: param.defaultValue,
                              hintText: param.paramType.defaultValueHint,
                              type: param.type,
                              onSave: (result) {
                                param.defaultValue = result;
                                _validateJsonField(i, param);
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ],
                    )
                  else if (param.type == 'boolean')
                    Text(
                      '布尔类型无需配置参数值。',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    _buildProviderCustomParamOptionRows(param, cs),
                ],
              ),
            ),
          );
        }),
    ];
  }
}
