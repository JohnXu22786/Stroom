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

  String _formatJsonError(String source, dynamic error) {
    if (error is FormatException) {
      final offset = error.offset;
      final msg = error.message;
      if (offset != null && offset >= 0 && offset <= source.length) {
        final before = source.substring(0, offset);
        final lines = before.split('\n');
        final line = lines.length;
        final col = lines.last.length + 1;
        return '第 $line 行第 $col 列: $msg';
      }
      return 'JSON 格式错误: $msg';
    }
    return 'JSON 格式不正确';
  }

  void _validateJsonField(int index, CustomParam param) {
    if (param.type == 'json' && param.defaultValue.trim().isNotEmpty) {
      try {
        jsonDecode(param.defaultValue.trim());
        _jsonErrors.remove(index);
      } catch (e) {
        _jsonErrors[index] = _formatJsonError(param.defaultValue, e);
      }
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
          liveError = _formatJsonError(editingController.text, e);
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
}
