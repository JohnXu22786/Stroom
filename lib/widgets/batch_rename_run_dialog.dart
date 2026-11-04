import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
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
        onChangesApplied: onChangesApplied,
      ),
    );

class _RunDialog extends StatefulWidget {
  final BatchRenamePlan? plan;
  final BatchRenameExecution? history;
  final ManifestBridge bridge;
  final RenameSnapshotReader readSnapshot;
  final RenameCallback renameFile;
  final RenameCallback renameFolder;
  final ValueChanged<List<BatchRenameChange>>? onChangesApplied;
  const _RunDialog({
    this.plan,
    this.history,
    required this.bridge,
    required this.readSnapshot,
    required this.renameFile,
    required this.renameFolder,
    this.onChangesApplied,
  });
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_run(false)),
      );
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
              onProgress: _progress,
            )
          : await executeBatchRename(
              plan: widget.plan!,
              bridge: widget.bridge,
              readSnapshot: widget.readSnapshot,
              renameFile: widget.renameFile,
              renameFolder: widget.renameFolder,
              shouldCancel: () => _cancel,
              onProgress: _progress,
            );
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
      if (mounted) {
        setState(
          () => _error =
              AppLocalizations.of(context)!.batchRunReadFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _close() => Navigator.pop(context, _history);

  String get _summary {
    final strings = AppLocalizations.of(context)!;
    final r = _result;
    if (r == null) return _error ?? strings.batchRunPreparing;
    final label = _undone ? strings.batchRunUndo : strings.batchRunRename;
    if (r.error != null && r.failed == null && r.completed.isEmpty)
      return strings.batchRunFailedAction(label);
    if (r.error == null && !r.cancelled)
      return strings.batchRunCompletedCount(r.completed.length, label);
    if (r.cancelled) {
      return strings.batchRunCancelledSummary(
        label,
        r.completed.length.toString(),
        (r.failed == null ? 0 : 1).toString(),
        r.remaining.toString(),
      );
    }
    return strings.batchRunSummary(
      r.completed.length,
      r.failed == null ? 0 : 1,
      label,
      r.remaining,
    );
  }

  Future<void> _copyReport() async {
    final r = _result!;
    try {
      await Clipboard.setData(
        ClipboardData(
          text: [
            _summary,
            for (final c in r.completed) '${c.sourcePath} → ${c.targetPath}',
            if (r.failed != null)
              AppLocalizations.of(context)!
                  .batchRunFailedItem(r.failed!.id, r.failed!.newBaseName),
            if (r.error != null) r.error!,
          ].join('\n'),
        ),
      );
      if (mounted)
        setState(
          () => _error = AppLocalizations.of(context)!.batchRunReportCopied,
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _error = AppLocalizations.of(context)!.batchRunCopyFailed,
        );
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
          title: Text(
            _running
                ? AppLocalizations.of(context)!.batchRunWorking(
                    _undoing
                        ? AppLocalizations.of(context)!.batchRunUndo
                        : AppLocalizations.of(context)!.batchRunRename,
                  )
                : AppLocalizations.of(context)!.batchRunTitle,
          ),
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
                      value: _total == 0 ? null : _done / _total,
                    ),
                    const SizedBox(height: 12),
                    Text('$_done / $_total'),
                    Text(_current,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (!_undoing)
                      Text(AppLocalizations.of(context)!.batchRunStoppedRetain),
                  ] else ...[
                    Text(_summary),
                    if (_error != null) Text(_error!),
                    if (_result?.error != null)
                      SelectableText(
                        _result!.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_result != null) ...[
                      for (final c in _result!.completed)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title:
                              Text('${c.oldName} → ${c.forward.newBaseName}'),
                          subtitle: Text('${c.sourcePath} → ${c.targetPath}'),
                        ),
                      if (_result!.failed != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.error_outline),
                          title: Text(_result!.failed!.id),
                          subtitle: Text(
                            AppLocalizations.of(context)!
                                .batchRunFailedRemaining,
                          ),
                        ),
                    ],
                    if (_history?.canUndo == true)
                      Text(AppLocalizations.of(context)!.batchRunUndoInfo),
                    if (_result != null && !_result!.verified)
                      Text(AppLocalizations.of(context)!.batchRunUncertain),
                  ],
                ],
              ),
            ),
          ),
          actions: _running
              ? [
                  if (_undoing)
                    Text(AppLocalizations.of(context)!.batchRunUndoing)
                  else
                    TextButton(
                      key: const Key('batch_run_cancel'),
                      onPressed:
                          _cancel ? null : () => setState(() => _cancel = true),
                      child: Text(
                        _cancel
                            ? AppLocalizations.of(context)!.batchRunStopping
                            : AppLocalizations.of(context)!
                                .batchRunStopRemaining,
                      ),
                    ),
                ]
              : [
                  if (_result != null)
                    TextButton(
                      onPressed: _copyReport,
                      child: Text(
                          AppLocalizations.of(context)!.batchRunCopyReport),
                    ),
                  if (_history?.canUndo == true)
                    TextButton(
                      key: const Key('batch_run_undo'),
                      onPressed: () => _run(true),
                      child: Text(
                        _undone
                            ? AppLocalizations.of(context)!
                                .batchRunUndoRemaining(
                                    _history!.completed.length)
                            : AppLocalizations.of(context)!
                                .batchRunUndoCompleted,
                      ),
                    ),
                  FilledButton(
                    key: const Key('batch_run_close'),
                    onPressed: _close,
                    child: Text(AppLocalizations.of(context)!.batchRunDone),
                  ),
                ],
        ),
      );
}
