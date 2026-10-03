import 'package:flutter/material.dart';

import '../services/connectivity_test_service.dart';

class ConnectivityTestDialog extends StatefulWidget {
  final String title;
  final String initialContent;
  final String note;
  final Future<void> Function(Map<String, dynamic> content) onSave;
  final Future<ConnectivityTestResult> Function(String content) onRun;

  const ConnectivityTestDialog({
    super.key,
    required this.title,
    required this.initialContent,
    required this.note,
    required this.onSave,
    required this.onRun,
  });

  @override
  State<ConnectivityTestDialog> createState() => _ConnectivityTestDialogState();
}

class _ConnectivityTestDialogState extends State<ConnectivityTestDialog> {
  late final TextEditingController _contentController;
  ConnectivityTestResult? _result;
  String? _saveError;
  bool _isRunning = false;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final content = ConnectivityTestService.decodeTestContent(
        _contentController.text,
      );
      await widget.onSave(content);
      if (!mounted) return;
      setState(() => _isSaved = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = _readableError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _run() async {
    setState(() {
      _isRunning = true;
      _result = null;
    });
    try {
      final result = await widget.onRun(_contentController.text);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _result = ConnectivityTestResult(
            succeeded: false,
            summary: '测试未能完成',
            details: _readableError(error),
            elapsed: Duration.zero,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  String _readableError(Object error) {
    if (error is FormatException) return error.message;
    return error.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds >= 1000) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} 秒';
    }
    return '${duration.inMilliseconds} 毫秒';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('${widget.title} · 连通性测试'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.note, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                minLines: 7,
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: '测试内容（JSON）',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  helperText:
                      '修改后可直接运行或保存。MCP 使用只读 tools/list；搜索工具可改 query/count；Todo 默认只读。',
                ),
                onChanged: (_) => setState(() {
                  _isSaved = false;
                  _saveError = null;
                  _result = null;
                }),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  '保存失败：$_saveError',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              if (_isSaved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('测试内容已保存',
                        style: TextStyle(color: colorScheme.primary)),
                  ],
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _ConnectivityResultCard(
                  result: _result!,
                  durationLabel: _formatDuration(_result!.elapsed),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isRunning || _isSaving ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        OutlinedButton.icon(
          onPressed: _isRunning || _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('保存内容'),
        ),
        FilledButton.icon(
          onPressed: _isRunning || _isSaving ? null : _run,
          icon: _isRunning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check, size: 18),
          label: Text(_isRunning ? '测试中…' : '运行测试'),
        ),
      ],
    );
  }
}

class _ConnectivityResultCard extends StatelessWidget {
  final ConnectivityTestResult result;
  final String durationLabel;

  const _ConnectivityResultCard({
    required this.result,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = result.succeeded ? colors.primary : colors.error;
    final background = result.succeeded
        ? colors.primaryContainer.withValues(alpha: 0.45)
        : colors.errorContainer.withValues(alpha: 0.45);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.succeeded ? Icons.check_circle : Icons.error_outline,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.summary,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
              Text(durationLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (result.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              result.details,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
