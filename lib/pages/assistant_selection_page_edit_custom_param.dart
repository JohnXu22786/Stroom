part of 'assistant_selection_page.dart';

void showEditCustomParameterDialog(
  BuildContext context,
  CustomParameter cp,
  void Function(String name, String type, dynamic value) onEdit,
) {
  final nameController = TextEditingController(text: cp.name);
  String type = cp.type;
  // Display JSON values using jsonEncode (proper JSON format) instead of
  // .toString() (Dart format like {key: value}) which would produce
  // invalid JSON and break round-trip editing.
  String initialValue;
  if (cp.type == 'json' && (cp.value is Map || cp.value is List)) {
    initialValue = jsonEncode(cp.value);
  } else {
    initialValue = cp.value?.toString() ?? '';
  }
  final valueController = TextEditingController(text: initialValue);
  String? jsonError;

  String fmtError(String source, dynamic error) {
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

  void validateJsonValue() {
    if (type == 'json' && valueController.text.trim().isNotEmpty) {
      try {
        jsonDecode(valueController.text.trim());
        jsonError = null;
      } catch (e) {
        jsonError = fmtError(valueController.text, e);
      }
    } else {
      jsonError = null;
    }
  }

  Widget buildCodeField(TextEditingController ctrl, String hint) {
    final lines = ctrl.text.split('\n');
    final lnCount = lines.length;
    final lnW = (lnCount.toString().length * 8.0 + 20.0).clamp(36.0, 80.0);
    const lh = 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: lnW,
          padding: const EdgeInsets.only(top: 12, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
                lnCount,
                (i) => SizedBox(
                      height: lh,
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            height: 1.3,
                          )),
                    )),
          ),
        ),
        Container(width: 1, color: Colors.grey.shade300),
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            autofocus: true,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, height: 1.3),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(8, 11, 8, 12),
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }

  void showValueFullscreenEditor(
    BuildContext dialogContext,
    StateSetter setDlgState,
  ) {
    final editingController = TextEditingController(text: valueController.text);
    String? liveError;

    void validateLive() {
      if (type == 'json' && editingController.text.trim().isNotEmpty) {
        try {
          jsonDecode(editingController.text.trim());
          liveError = null;
        } catch (e) {
          liveError = fmtError(editingController.text, e);
        }
      } else {
        liveError = null;
      }
    }

    validateLive();

    showDialog(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFsState) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(type == 'json' ? Icons.data_object : Icons.edit_note,
                        size: 20,
                        color: type == 'json' ? Colors.amber.shade700 : null),
                    const SizedBox(width: 8),
                    const Text('编辑参数值',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    if (type == 'json')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('JSON',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900)),
                      ),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          editingController.dispose();
                          Navigator.pop(ctx);
                        },
                        tooltip: '取消'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f5f5),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: buildCodeField(editingController, ''),
                  ),
                ),
                if (liveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(liveError!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade800,
                                      fontFamily: 'monospace'))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (liveError != null)
                      Text('JSON 格式有误，请修正后再保存',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade400)),
                    const Spacer(),
                    TextButton(
                        onPressed: () {
                          editingController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: const Text('取消')),
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
                              setDlgState(() {
                                valueController.text = text;
                                valueController.selection =
                                    TextSelection.fromPosition(
                                        TextPosition(offset: text.length));
                                validateJsonValue();
                              });
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

  // Initial validation
  validateJsonValue();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('编辑自定义参数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '参数名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'string', child: Text('字符串')),
                DropdownMenuItem(value: 'number', child: Text('数字')),
                DropdownMenuItem(value: 'boolean', child: Text('布尔')),
                DropdownMenuItem(value: 'json', child: Text('JSON')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setDlgState(() {
                    type = v;
                    validateJsonValue();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: '值',
                      border: const OutlineInputBorder(),
                      errorText: jsonError,
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) {
                      validateJsonValue();
                      setDlgState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: '全屏编辑',
                  onPressed: () {
                    showValueFullscreenEditor(ctx, setDlgState);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              if (jsonError != null) return;
              dynamic value = valueController.text.trim();
              if (type == 'number') {
                value = double.tryParse(value) ?? int.tryParse(value) ?? value;
              } else if (type == 'boolean') {
                value = (value as String).toLowerCase() == 'true';
              } else if (type == 'json') {
                try {
                  value = jsonDecode(value as String);
                } catch (_) {
                  // Keep as string if not valid JSON
                }
              }
              onEdit(name, type, value);
              nameController.dispose();
              valueController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
