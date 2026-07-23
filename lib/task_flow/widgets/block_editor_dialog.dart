import 'package:flutter/material.dart';
import '../models/task_flow_definition.dart';
import '../models/block_type_definition.dart';

/// A dialog for editing the parameters of a [TaskFlowBlock] instance.
///
/// Shows fields for each parameter defined in the block's
/// [BlockTypeDefinition], pre-populated with the block's current values.
/// Returns updated [TaskFlowBlock] if the user confirms, or null if cancelled.
Future<TaskFlowBlock?> showBlockEditorDialog(
  BuildContext context, {
  required TaskFlowBlock block,
}) {
  return showDialog<TaskFlowBlock>(
    context: context,
    builder: (ctx) => _BlockEditorDialog(block: block),
  );
}

class _BlockEditorDialog extends StatefulWidget {
  final TaskFlowBlock block;

  const _BlockEditorDialog({required this.block});

  @override
  State<_BlockEditorDialog> createState() => _BlockEditorDialogState();
}

class _BlockEditorDialogState extends State<_BlockEditorDialog> {
  late Map<String, dynamic> _params;
  late final BlockTypeDefinition? _definition;
  late final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _params = Map<String, dynamic>.from(widget.block.params);
    _definition = widget.block.getDefinition();

    // Initialize TextEditingControllers for string-type params
    if (_definition != null) {
      for (final p in _definition!.params) {
        if (p.type == BlockParamType.string ||
            p.type == BlockParamType.modelSelector ||
            p.type == BlockParamType.secret) {
          _controllers[p.key] = TextEditingController(
            text: _params[p.key]?.toString() ?? '',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_definition == null) {
      return AlertDialog(
        title: const Text('未知功能块'),
        content: Text('功能块类型 "${widget.block.typeKey}" 未注册'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    final def = _definition!;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(def.icon, size: 16, color: def.color),
          ),
          const SizedBox(width: 8),
          Text('${def.label} 参数'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '输入: ${def.inputType.label}  →  输出: ${def.outputType.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (def.params.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      '该功能块无额外参数',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...def.params.map((param) => _buildParamField(param, cs)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.block.copyWithParams(_params);
            Navigator.pop(context, updated);
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildParamField(BlockParamDefinition param, ColorScheme cs) {
    final value = _params[param.key];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${param.label}${param.required ? ' *' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          _buildInputField(param, value, cs),
          if (param.hintText != null && param.hintText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                param.hintText!,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(
      BlockParamDefinition param, dynamic value, ColorScheme cs) {
    switch (param.type) {
      case BlockParamType.string:
      case BlockParamType.modelSelector:
      case BlockParamType.secret:
        final controller = _controllers[param.key] ??
            TextEditingController(text: value?.toString() ?? '');
        // Ensure new controllers are tracked
        if (_controllers[param.key] == null) {
          _controllers[param.key] = controller;
        }
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          obscureText: param.type == BlockParamType.secret,
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => _params[param.key] = v,
        );

      case BlockParamType.number:
        return TextField(
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: (v) {
            final parsed = num.tryParse(v);
            _params[param.key] = parsed ?? 0;
          },
        );

      case BlockParamType.boolean:
        return SwitchListTile(
          value: value == true,
          onChanged: (v) => setState(() => _params[param.key] = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            value == true ? '是' : '否',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        );

      case BlockParamType.filePath:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value?.toString().isNotEmpty == true
                      ? value.toString()
                      : '默认 (根目录)',
                  style: TextStyle(
                    fontSize: 13,
                    color: value?.toString().isNotEmpty == true
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickFolder(param.key),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('选择', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _pickFolder(String key) async {
    final currentValue = _params[key]?.toString() ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final textController = TextEditingController(text: currentValue);
        return AlertDialog(
          title: const Text('输入文件夹名称'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: '例如: audio_output',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, textController.text),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _params[key] = result);
    }
  }
}
