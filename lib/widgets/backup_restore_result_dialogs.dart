import 'package:flutter/material.dart';

import 'constrained_text.dart';

/// Result shown after restoring data requires an app restart.
class BackupRestoreRestartDialog extends StatelessWidget {
  const BackupRestoreRestartDialog({
    super.key,
    required this.title,
    required this.message,
    required this.exitLabel,
    required this.restartLabel,
    required this.onExit,
    required this.onRestart,
    this.icon = Icons.check_circle,
    this.iconColor = const Color(0xFF43A047),
  });

  final String title;
  final String message;
  final String exitLabel;
  final String restartLabel;
  final VoidCallback onExit;
  final VoidCallback onRestart;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onExit,
            child: ConstrainedText(
              exitLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: onRestart,
            child: ConstrainedText(
              restartLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

/// Result shown when selected backup categories were skipped.
class BackupRestoreSkippedDialog extends StatelessWidget {
  const BackupRestoreSkippedDialog({
    super.key,
    required this.title,
    required this.message,
    required this.acknowledgeLabel,
    required this.onAcknowledge,
  });

  final String title;
  final String message;
  final String acknowledgeLabel;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: ConstrainedText(title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: onAcknowledge,
            child: ConstrainedText(
              acknowledgeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
