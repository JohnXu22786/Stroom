import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
      _isSaved = false;
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
            summary:
                AppLocalizations.of(context)!.connectivityTestFailedSummary,
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
    final localizations = AppLocalizations.of(context)!;
    if (duration.inMilliseconds >= 1000) {
      return localizations.connectivityTestDurationSeconds(
        (duration.inMilliseconds / 1000).toStringAsFixed(2),
      );
    }
    return localizations.connectivityTestDurationMilliseconds(
      duration.inMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(localizations.connectivityTestTitle(widget.title)),
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
                enabled: !_isRunning && !_isSaving,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: localizations.connectivityTestJsonLabel,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  helperText: localizations.connectivityTestJsonHelp,
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
                  localizations.connectivityTestSaveFailed(_saveError!),
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              if (_isSaved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      localizations.connectivityTestSaved,
                      style: TextStyle(color: colorScheme.primary),
                    ),
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
          child: Text(localizations.connectivityTestClose),
        ),
        OutlinedButton.icon(
          onPressed: _isRunning || _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(localizations.connectivityTestSaveContent),
        ),
        FilledButton.icon(
          onPressed: _isRunning || _isSaving ? null : _run,
          icon: _isRunning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check, size: 18),
          label: Text(
            _isRunning
                ? localizations.connectivityTestTesting
                : localizations.connectivityTestRun,
          ),
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
