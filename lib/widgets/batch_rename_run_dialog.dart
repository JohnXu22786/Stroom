import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/batch_rename.dart';
import '../utils/batch_rename_execution.dart';
import '../utils/manifest_bridge.dart';

Future<BatchRenameExecution?> showBatchRenameRunDialog({
  required BuildContext context,
  BatchRenamePlan? plan,
  BatchRenameExecution? history,
  required ManifestBridge bridge,
  required RenameSnapshotReader readSnapshot,
  required RenameCallback renameFile,
  required RenameCallback renameFolder,
  ValueChanged<List<BatchRenameChange>>? onChangesApplied,
}) =>
    showDialog<BatchRenameExecution>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RunDialog(
            plan: plan,
            history: history,
            bridge: bridge,
            readSnapshot: readSnapshot,
            renameFile: renameFile,
            renameFolder: renameFolder,
            onChangesApplied: onChangesApplied));

class _RunDialog extends StatefulWidget {
  final BatchRenamePlan? plan;
  final BatchRenameExecution? history;
  final ManifestBridge bridge;
  final RenameSnapshotReader readSnapshot;
  final RenameCallback renameFile;
  final RenameCallback renameFolder;
  final ValueChanged<List<BatchRenameChange>>? onChangesApplied;
  const _RunDialog(
      {this.plan,
      this.history,
      required this.bridge,
      required this.readSnapshot,
      required this.renameFile,
      required this.renameFolder,
      this.onChangesApplied});
  @override
  State<_RunDialog> createState() => _RunDialogState();
}

class _RunDialogState extends State<_RunDialog> {
  BatchRenameExecution? _result;
  BatchRenameExecution? _history;
  bool _running = false;
  bool _cancel = false;
  bool _undone = false;
  bool _undoing = false;
  int _done = 0;
  int _total = 0;
  String _current = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.history;
    _history = widget.history;
    if (_result == null) {
      _running = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_run(false)));
    }
  }

  void _progress(int done, int total, String name) {
    if (mounted)
      setState(() {
        _done = done;
        _total = total;
        _current = name;
      });
  }

  Future<void> _run(bool undo) async {
    setState(() {
      _running = true;
      _undoing = undo;
      _error = null;
      _done = 0;
    });
    try {
      final result = undo
          ? await undoBatchRename(
              execution: _history!,
              readSnapshot: widget.readSnapshot,
              renameFile: widget.renameFile,
              renameFolder: widget.renameFolder,
              onProgress: _progress)
          : await executeBatchRename(
              plan: widget.plan!,
              bridge: widget.bridge,
              readSnapshot: widget.readSnapshot,
              renameFile: widget.renameFile,
              renameFolder: widget.renameFolder,
              shouldCancel: () => _cancel,
              onProgress: _progress);
      if (mounted) {
        setState(() {
          _history =
              undo ? remainingBatchRenameHistory(_history!, result) : result;
          _result = result;
          _undone = undo;
        });
        widget.onChangesApplied?.call(result.completed);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '无法读取文件列表：$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _close() => Navigator.pop(context, _history);

  String get _summary {
    final r = _result;
    if (r == null) return _error ?? '准备中…';
    final label = _undone ? '撤销' : '重命名';
    if (r.error != null && r.failed == null && r.completed.isEmpty)
      return '未能执行$label';
    if (r.error == null && !r.cancelled)
      return '已${label} ${r.completed.length} 项';
    return '${label}${r.cancelled ? '已停止' : '完成'}：成功 ${r.completed.length} 项，失败 ${r.failed == null ? 0 : 1} 项${r.remaining > 0 ? '，未执行 ${r.remaining} 项' : ''}';
  }

  Future<void> _copyReport() async {
    final r = _result!;
    try {
      await Clipboard.setData(ClipboardData(
          text: [
        _summary,
        for (final c in r.completed) '${c.sourcePath} → ${c.targetPath}',
        if (r.failed != null) '失败：${r.failed!.id} → ${r.failed!.newBaseName}',
        if (r.error != null) r.error!,
      ].join('\n')));
      if (mounted) setState(() => _error = '已复制执行报告');
    } catch (_) {
      if (mounted) setState(() => _error = '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_running) _close();
      },
      child: AlertDialog(
        key: const Key('batch_run_dialog'),
        title: Text(_running ? '正在${_undoing ? '撤销' : '重命名'}…' : '批量重命名结果'),
        content: SizedBox(
            width: 540,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                    key: const Key('batch_run_report'),
                    shrinkWrap: true,
                    children: [
                      if (_running) ...[
                        LinearProgressIndicator(
                            value: _total == 0 ? null : _done / _total),
                        const SizedBox(height: 12),
                        Text('$_done / $_total'),
                        Text(_current,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (!_undoing) const Text('停止后会保留当前已完成的项目，可在结果页撤销。'),
                      ] else ...[
                        Text(_summary),
                        if (_error != null) Text(_error!),
                        if (_result?.error != null)
                          SelectableText(_result!.error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        if (_result != null) ...[
                          for (final c in _result!.completed)
                            ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(
                                    '${c.oldName} → ${c.forward.newBaseName}'),
                                subtitle:
                                    Text('${c.sourcePath} → ${c.targetPath}')),
                          if (_result!.failed != null)
                            ListTile(
                                dense: true,
                                leading: const Icon(Icons.error_outline),
                                title: Text(_result!.failed!.id),
                                subtitle: const Text('失败；后续项目未执行')),
                        ],
                        if (_history?.canUndo == true)
                          const Text('撤销会恢复本次已成功项目的原名；后续列表变化时将拒绝撤销。'),
                        if (_result != null && !_result!.verified)
                          const Text('有项目状态无法确认，请检查文件列表；为避免覆盖，不提供自动撤销。'),
                      ],
                    ]))),
        actions: _running
            ? [
                if (_undoing)
                  const Text('正在恢复原名，请稍候')
                else
                  TextButton(
                      key: const Key('batch_run_cancel'),
                      onPressed:
                          _cancel ? null : () => setState(() => _cancel = true),
                      child: Text(_cancel ? '正在停止…' : '停止后续操作'))
              ]
            : [
                if (_result != null)
                  TextButton(onPressed: _copyReport, child: const Text('复制报告')),
                if (_history?.canUndo == true)
                  TextButton(
                      key: const Key('batch_run_undo'),
                      onPressed: () => _run(true),
                      child: Text(_undone
                          ? '继续撤销剩余 ${_history!.completed.length} 项'
                          : '撤销已完成改名')),
                FilledButton(
                    key: const Key('batch_run_close'),
                    onPressed: _close,
                    child: const Text('完成'))
              ],
      ));
}
