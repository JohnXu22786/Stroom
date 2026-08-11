import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ocr_instructions_provider.dart';

// ============================================================================
// 识别指令管理对话框 — 在 OCR 页面统一设置通用识别指令
// ============================================================================

/// Display label for an instruction: its name, or the first line of the
/// content when unnamed (truncated to 20 chars).
String ocrInstructionLabel(OcrInstruction instruction) {
  final name = instruction.name;
  if (name.isNotEmpty) return name;
  final firstLine = instruction.content.trim().split('\n').first.trim();
  return firstLine.length > 20 ? '${firstLine.substring(0, 20)}…' : firstLine;
}

/// Dialog for managing the generic OCR instructions (add / edit / delete).
class OcrInstructionManageDialog extends ConsumerStatefulWidget {
  const OcrInstructionManageDialog({super.key});

  @override
  ConsumerState<OcrInstructionManageDialog> createState() =>
      _OcrInstructionManageDialogState();
}

class _OcrInstructionManageDialogState
    extends ConsumerState<OcrInstructionManageDialog> {
  Future<void> _editInstruction(int index) async {
    final instructions = ref.read(ocrInstructionsProvider);
    if (index < 0 || index >= instructions.length) return;
    final existing = instructions[index];
    final result = await showDialog<(String name, String content)>(
      context: context,
      builder: (_) => _InstructionEditorDialog(
        initialName: existing.name,
        initialContent: existing.content,
      ),
    );
    if (result == null || !mounted) return;
    await ref
        .read(ocrInstructionsProvider.notifier)
        .update(index, result.$1, result.$2);
  }

  Future<void> _addInstruction() async {
    final result = await showDialog<(String name, String content)>(
      context: context,
      builder: (_) => const _InstructionEditorDialog(),
    );
    if (result == null || !mounted) return;
    await ref.read(ocrInstructionsProvider.notifier).add(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final instructions = ref.watch(ocrInstructionsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.edit_note, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 10),
          const Text(
            '管理识别指令',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '指令为通用设置，对所有识别模型生效。不选择时仅发送图片。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: instructions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '暂无指令',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: instructions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final instruction = instructions[index];
                          final name = instruction.name;
                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ocrInstructionLabel(instruction),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      if (name.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          instruction.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: '编辑指令',
                                  onPressed: () => _editInstruction(index),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: cs.error,
                                  ),
                                  tooltip: '删除指令',
                                  onPressed: () => ref
                                      .read(ocrInstructionsProvider.notifier)
                                      .remove(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: _addInstruction,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加指令'),
        ),
      ],
    );
  }
}

/// Editor dialog for a single instruction (name optional, content required).
class _InstructionEditorDialog extends StatefulWidget {
  final String initialName;
  final String initialContent;

  const _InstructionEditorDialog({
    this.initialName = '',
    this.initialContent = '',
  });

  @override
  State<_InstructionEditorDialog> createState() =>
      _InstructionEditorDialogState();
}

class _InstructionEditorDialogState extends State<_InstructionEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      (_nameController.text.trim(), _contentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _contentController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(
        widget.initialName.isEmpty && widget.initialContent.isEmpty
            ? '添加指令'
            : '编辑指令',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '指令名称（可选）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '指令内容',
                border: OutlineInputBorder(),
                isDense: true,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
