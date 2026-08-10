part of 'provider_settings_panel.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ProviderSettingsPanelCustomParamsExt on _ProviderSettingsPanelState {
  // ===================================================================
  // 自定义参数（CustomParam）选项值胶囊块（与推理力度同款）
  // ===================================================================

  /// 长按拖拽排序选项：把 [from] 移到 [to] 的位置。
  void _moveProviderCustomParamOptionTo(
      CustomParam param, String from, String to) {
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

  /// 添加选项值（对话框输入）。
  Future<void> _addProviderCustomParamOptionWithDialog(
      CustomParam param) async {
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
      }
    });
  }

  /// 选项值区：胶囊块（长按拖拽排序，右上角删除）。
  Widget _buildProviderCustomParamOptionBlocks(
      CustomParam param, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选项值（点右上角 × 删除，长按拖拽排序）',
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
              _buildProviderCustomParamOptionBlock(param, value, cs),
          ],
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加选项', style: TextStyle(fontSize: 13)),
          onPressed: () => _addProviderCustomParamOptionWithDialog(param),
        ),
      ],
    );
  }

  Widget _buildProviderCustomParamOptionBlock(
    CustomParam param,
    String value,
    ColorScheme cs,
  ) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Text(
        value,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
    );

    final withDelete = Stack(
      clipBehavior: Clip.none,
      children: [
        pill,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                param.options.remove(value);
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
          _moveProviderCustomParamOptionTo(param, details.data, value),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: value,
          delay: const Duration(milliseconds: 330),
          childWhenDragging: Opacity(opacity: 0.3, child: withDelete),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.8, child: withDelete),
          ),
          child: withDelete,
        );
      },
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
                  // 值区按类型区分（与推理参数同款）：
                  // string/number → 选项值胶囊块；json/boolean → 默认参数值。
                  if (param.type == 'string' || param.type == 'number')
                    _buildProviderCustomParamOptionBlocks(param, cs)
                  else
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
                    ),
                ],
              ),
            ),
          );
        }),
    ];
  }
}
