import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

import 'constrained_text.dart';

class ClearSelectedDataConfirmationDialog extends StatefulWidget {
  const ClearSelectedDataConfirmationDialog({
    required this.labels,
    required this.browserWebsiteDataUnsupported,
  });

  final List<String> labels;
  final bool browserWebsiteDataUnsupported;

  @override
  State<ClearSelectedDataConfirmationDialog> createState() =>
      _ClearSelectedDataConfirmationDialogState();
}

class _ClearSelectedDataConfirmationDialogState
    extends State<ClearSelectedDataConfirmationDialog> {
  static const _countdownDuration = 10;
  int _secondsRemaining = _countdownDuration;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: ConstrainedText(
        AppLocalizations.of(context)!.backupRestoreConfirmClear,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.backupRestoreClearCategoriesIntro),
          const SizedBox(height: 12),
          ...widget.labels.map(
            (label) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          if (widget.browserWebsiteDataUnsupported) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .backupRestoreBrowserClearUnsupported,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          if (widget.labels.length < 9) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .backupRestoreUnselectedUnchanged,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.backupRestoreClearWarning,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: ConstrainedText(
            AppLocalizations.of(context)!.backupRestoreCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          onPressed: _secondsRemaining == 0
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: ConstrainedText(
            _secondsRemaining == 0
                ? AppLocalizations.of(context)!.backupRestoreClearSelected
                : AppLocalizations.of(context)!
                      .backupRestoreConfirmClearCountdown(_secondsRemaining),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
