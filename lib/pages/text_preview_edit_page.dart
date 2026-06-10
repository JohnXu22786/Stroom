import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/text_manifest.dart';

/// 文本预览/编辑页面 - 查看和编辑文本内容
///
/// 查看模式：展示只读文本，右上角显示「编辑」按钮
/// 编辑模式：展示可编辑文本，右上角显示「保存」和「放弃」按钮
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

  @override
  void initState() {
    super.initState();
    _originalContent = widget.initialContent ?? '';
    _contentController = TextEditingController(text: _originalContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// 进入编辑模式，保存当前内容作为原始备份
  void _enterEditMode() {
    setState(() {
      _originalContent = _contentController.text;
      _isEditMode = true;
    });
  }

  /// 放弃更改，恢复原始内容并退出编辑模式
  void _discardChanges() {
    setState(() {
      _contentController.text = _originalContent;
      _isEditMode = false;
    });
  }

  /// 保存内容到文本文件
  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final newContent = _contentController.text;
      final bytes = Uint8List.fromList(newContent.codeUnits);
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

  /// 构建 AppBar 操作按钮
  List<Widget> _buildAppBarActions() {
    if (_isEditMode) {
      return [
        TextButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 20),
          label: Text(_isSaving ? '保存中...' : '保存'),
        ),
        TextButton.icon(
          onPressed: _isSaving ? null : _discardChanges,
          icon: const Icon(Icons.close, size: 20),
          label: const Text('放弃'),
        ),
      ];
    }
    // 查看模式：编辑按钮
    return [
      TextButton.icon(
        icon: const Icon(Icons.edit, size: 20),
        label: const Text('编辑'),
        onPressed: _enterEditMode,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.file.name}.${widget.file.format}';

    return PopScope(
      canPop: !_isEditMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 编辑模式下有未保存的更改，询问用户
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
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _contentController.text,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
      ),
    );
  }
}
