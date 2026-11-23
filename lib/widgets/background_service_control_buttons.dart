import 'package:flutter/material.dart';

import 'constrained_text.dart';

/// Production service actions, shared by the settings page and its visual QA
/// fixture so the constrained labels are captured in their real button layout.
class BackgroundServiceControlButtons extends StatelessWidget {
  const BackgroundServiceControlButtons({
    super.key,
    required this.isServiceRunning,
    required this.isOperating,
    required this.startLabel,
    required this.stopLabel,
    required this.restartLabel,
    required this.redetectLabel,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onRedetect,
  });

  final bool isServiceRunning;
  final bool isOperating;
  final String startLabel;
  final String stopLabel;
  final String restartLabel;
  final String redetectLabel;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onRedetect;

  @override
  Widget build(BuildContext context) {
    final operationIndicator = const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    return Column(
      children: [
        if (isServiceRunning)
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: isOperating ? null : onStop,
                  icon: isOperating
                      ? operationIndicator
                      : const Icon(Icons.stop, size: 18),
                  label: ConstrainedText(
                    stopLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isOperating ? null : onRestart,
                  icon: isOperating
                      ? operationIndicator
                      : const Icon(Icons.restart_alt, size: 18),
                  label: ConstrainedText(
                    restartLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: isOperating ? null : onStart,
              icon: isOperating
                  ? operationIndicator
                  : const Icon(Icons.play_arrow, size: 18),
              label: ConstrainedText(
                startLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isOperating ? null : onRedetect,
            icon: const Icon(Icons.refresh, size: 18),
            label: ConstrainedText(
              redetectLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
