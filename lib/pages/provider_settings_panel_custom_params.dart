part of 'provider_settings_panel.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelCustomParamsExt on _ProviderSettingsPanelState {
  /// 自定义参数选项值区（照搬本面板推理力度的行式样式）：
  /// 多值文本行 + 把手排序 + 删除 + 添加选项。
  Widget _buildProviderCustomParamOptionRows(
      CustomParam param, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选项值（拖动把手排序）',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
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
            return Padding(
              key: ValueKey('custom-opt-$j'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: j,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child:
                          Icon(Icons.drag_handle, size: 20, color: Colors.grey),
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
                        setState(() {
                          param.options.removeAt(j);
                        });
                      },
                      tooltip: '删除选项',
                    ),
                ],
              ),
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

  Widget _buildCodeEditorTextField(
    TextEditingController controller,
    String hintText,
    String type,
  ) {
    final lines = controller.text.split('\n');
    final lineCount = lines.length;
    final digitCount = lineCount.toString().length;
    final lineNumWidth = (digitCount * 8.0 + 20.0).clamp(36.0, 80.0);
    const lineHeight = 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers
        Container(
          width: lineNumWidth,
          padding: const EdgeInsets.only(top: 12, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(lineCount, (i) {
              return SizedBox(
                height: lineHeight,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
              );
            }),
          ),
        ),
        Container(width: 1, color: Colors.grey.shade300),
        // Editable text area
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.3,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(8, 11, 8, 12),
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }

  void _showValueFullscreenEditor(
    BuildContext context,
    String currentValue,
    ValueChanged<String> onSave,
    String hintText, {
    String type = 'string',
  }) {
    final editingController = TextEditingController(text: currentValue);
    String? liveError;

    void validateLive() {
      if (type == 'json' && editingController.text.trim().isNotEmpty) {
        try {
          jsonDecode(editingController.text.trim());
          liveError = null;
        } catch (e) {
          liveError = formatJsonError(editingController.text, e);
        }
      } else {
        liveError = null;
      }
    }

    validateLive();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Title bar
                Row(
                  children: [
                    Icon(
                      type == 'json' ? Icons.data_object : Icons.edit_note,
                      size: 20,
                      color: type == 'json' ? Colors.amber.shade700 : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '编辑参数值',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (type == 'json')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'JSON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        editingController.dispose();
                        Navigator.pop(ctx);
                      },
                      tooltip: '取消',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Code editor area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f5f5),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCodeEditorTextField(
                      editingController,
                      hintText,
                      type,
                    ),
                  ),
                ),
                // Error message bar
                if (liveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              liveError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  children: [
                    if (liveError != null)
                      Text(
                        'JSON 格式有误，请修正后再保存',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        editingController.dispose();
                        Navigator.pop(ctx);
                      },
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('确定'),
                      onPressed: liveError != null
                          ? null
                          : () {
                              final text = editingController.text;
                              editingController.dispose();
                              Navigator.pop(ctx);
                              onSave(text);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                            errorText: isDuplicate ? '已存在该参数' : null,
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
                  // 值区按类型区分（照搬本面板推理力度的处理）：
                  // string/number → 选项值文本行（多值、可编辑、把手排序）；
                  // json → 默认参数值输入框；boolean → 无参数值。
                  if (param.type == 'json')
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: param.defaultValue,
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
                              isDense: true,
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
                            _showValueFullscreenEditor(
                              context,
                              param.defaultValue,
                              (result) {
                                param.defaultValue = result;
                                _validateJsonField(i, param);
                                setState(() {});
                              },
                              param.paramType.defaultValueHint,
                              type: param.type,
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
