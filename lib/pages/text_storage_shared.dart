import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/text_manifest.dart';

class TextCreatePage extends StatefulWidget {
  final String initialFolder;

  const TextCreatePage({super.key, this.initialFolder = ''});

  @override
  State<TextCreatePage> createState() => TextCreatePageState();
}

class TextCreatePageState extends State<TextCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;
  String _selectedFormat = 'txt';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';

      await TextManifest.writeText(storageFileName, content);
      await TextManifest.addRecord(TextRecord(
        name: title,
        hash: hash,
        format: _selectedFormat,
        createdAt: DateTime.now(),
        size: bytes.length,
        folder: widget.initialFolder,
        textLength: content.length,
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
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建文本'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '输入文本标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFormat,
                    decoration: const InputDecoration(
                      labelText: '格式',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'txt', child: Text('txt')),
                      DropdownMenuItem(value: 'md', child: Text('md')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedFormat = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '文本内容',
                  hintText: '输入文本内容...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
