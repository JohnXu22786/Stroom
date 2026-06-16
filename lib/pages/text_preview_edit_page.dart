import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/text_manifest.dart';

/// 文本预览/编辑页面 - 查看和编辑文本内容
///
/// 查看模式：展示只读文本，右上角显示「编辑」图标按钮
/// 编辑模式：展示可编辑文本，右上角显示「撤销」「重做」「保存」「放弃」图标按钮
/// 未产生修改时直接返回，有修改才弹出二次确认对话框
class TextPreviewEditPage extends StatefulWidget {
  final TextRecord file;
  final String? initialContent;

  const TextPreviewEditPage({
    super.key,
    required this.file,
    this.initialContent,
  });

  @override
  State<TextPreviewEditPage> createState() => _TextPreviewEditPageState();
}

class _TextPreviewEditPageState extends State<TextPreviewEditPage> {
  bool _isEditMode = false;
  bool _isSaving = false;
  late TextEditingController _contentController;
  late String _originalContent;
  bool _hasChanges = false;

  // 撤销/重做栈
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isUndoingOrRedoing = false;

  // 字号设置
  double _fontSize = 14;
  static const double _minFontSize = 10;
  static const double _maxFontSize = 28;

  @override
  void initState() {
    super.initState();
    _originalContent = widget.initialContent ?? '';
    _contentController = TextEditingController(text: _originalContent);
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    super.dispose();
  }

  /// 文本内容变化监听
  void _onContentChanged() {
    if (_isUndoingOrRedoing) return;

    final currentText = _contentController.text;
    // 仅在文本实际发生变化时记录到撤销栈
    if (_isEditMode && (_undoStack.isEmpty || currentText != _undoStack.last)) {
      _undoStack.add(currentText);
      _redoStack.clear();
    }
    _updateHasChanges();
  }

  /// 更新是否有未保存的更改
  void _updateHasChanges() {
    final changed = _contentController.text != _originalContent;
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  /// 进入编辑模式，保存当前内容作为原始备份
  void _enterEditMode() {
    setState(() {
      _originalContent = _contentController.text;
      _isEditMode = true;
      _hasChanges = false;
      _undoStack.clear();
      _redoStack.clear();
      // 将初始状态推入撤销栈
      _undoStack.add(_originalContent);
    });
  }

  /// 撤销：回到上一个文本状态
  void _undo() {
    if (_undoStack.length <= 1) return;

    _isUndoingOrRedoing = true;
    // 当前状态出栈，推入重做栈
    final currentState = _undoStack.removeLast();
    _redoStack.add(currentState);
    // 恢复到上一个状态
    _contentController.text = _undoStack.last;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
    _isUndoingOrRedoing = false;

    setState(() {
      _hasChanges = _contentController.text != _originalContent;
    });
  }

  /// 重做：恢复被撤销的文本状态
  void _redo() {
    if (_redoStack.isEmpty) return;

    _isUndoingOrRedoing = true;
    // 从重做栈取出，推入撤销栈
    final nextState = _redoStack.removeLast();
    _undoStack.add(nextState);
    _contentController.text = nextState;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
    _isUndoingOrRedoing = false;

    setState(() {
      _hasChanges = _contentController.text != _originalContent;
    });
  }

  /// 放弃更改，恢复原始内容并退出编辑模式
  void _discardChanges() {
    setState(() {
      _contentController.text = _originalContent;
      _isEditMode = false;
      _hasChanges = false;
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  /// 字号调节弹窗（数字在上，滑块在下）
  void _showFontSizePopup() {
    double temp = _fontSize;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('字号调整'),
          content: SizedBox(
            width: 260,
            height: 80,
            child: Column(
              children: [
                Text(
                  '${temp.toInt()}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: temp,
                    min: _minFontSize,
                    max: _maxFontSize,
                    divisions: ((_maxFontSize - _minFontSize) / 2).toInt(),
                    label: '${temp.toInt()}',
                    onChanged: (v) {
                      temp = v.roundToDouble();
                      setDialogState(() {});
                      setState(() => _fontSize = temp);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存内容到文本文件
  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final newContent = _contentController.text;
      final bytes = Uint8List.fromList(utf8.encode(newContent));
      final newHash = computeTextHash(bytes);
      final oldStorageFileName = widget.file.storageFileName;
      final newStorageFileName = '$newHash.txt';

      // 写入新内容到新的存储文件（基于新 hash 的文件名）
      await TextManifest.writeText(newStorageFileName, newContent);

      // 删除旧的存储文件
      await TextManifest.deleteFile(oldStorageFileName);

      // 更新 manifest 记录为新 hash
      await TextManifest.updateRecord(TextRecord(
        id: widget.file.id,
        name: widget.file.name,
        hash: newHash,
        format: widget.file.format,
        createdAt: widget.file.createdAt,
        size: bytes.length,
        folder: widget.file.folder,
        textLength: newContent.length,
      ));

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 构建 AppBar 操作按钮（仅图标）
  List<Widget> _buildAppBarActions() {
    if (_isEditMode) {
      return [
        // 字号调整按钮
        IconButton(
          icon: const Icon(Icons.format_size, size: 20),
          tooltip: '字号调整',
          onPressed: _showFontSizePopup,
        ),
        // 撤销按钮
        IconButton(
          icon: const Icon(Icons.undo, size: 20),
          tooltip: '撤销',
          onPressed: (_undoStack.length > 1) && !_isSaving ? _undo : null,
        ),
        // 重做按钮
        IconButton(
          icon: const Icon(Icons.redo, size: 20),
          tooltip: '重做',
          onPressed: _redoStack.isNotEmpty && !_isSaving ? _redo : null,
        ),
        // 保存按钮（仅图标）
        if (_isSaving)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            tooltip: '保存',
            onPressed: _save,
          ),
        // 放弃按钮（仅图标）
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: '放弃',
          onPressed: (_hasChanges && !_isSaving) ? _discardChanges : null,
        ),
      ];
    }
    // 查看模式：编辑按钮（仅图标）
    return [
      IconButton(
        icon: const Icon(Icons.edit, size: 20),
        tooltip: '编辑',
        onPressed: _enterEditMode,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.file.name}.${widget.file.format}';

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 有未保存的更改，询问用户
        final navigator = Navigator.of(context);
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃编辑？'),
            content: const Text('你有未保存的更改，确定要放弃吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续编辑'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && mounted) {
          setState(() {
            _isEditMode = false;
            _contentController.text = _originalContent;
            _undoStack.clear();
            _redoStack.clear();
          });
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: _buildAppBarActions(),
        ),
        body: _isEditMode
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontSize: _fontSize, height: 1.5),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _contentController.text,
                  style: TextStyle(fontSize: _fontSize, height: 1.5),
                ),
              ),
      ),
    );
  }
}
