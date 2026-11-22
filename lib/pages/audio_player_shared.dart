import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../providers/provider_config.dart';

import '../widgets/constrained_text.dart';

// ============================================================================
// StreamModelOption — data class for streaming model selection
// ============================================================================

class StreamModelOption {
  final ModelConfig model;
  final ProviderConfigItem configItem;

  const StreamModelOption(this.model, this.configItem);
}

// ============================================================================
// AudioPlayerErrorView — error state display with retry
// ============================================================================

class AudioPlayerErrorView extends StatelessWidget {
  final String errorMessage;
  final String diagnosticInfo;
  final VoidCallback onRetry;

  const AudioPlayerErrorView({
    super.key,
    required this.errorMessage,
    required this.diagnosticInfo,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                constraints.maxHeight > 48 ? constraints.maxHeight - 48 : 0,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.audioPlayerFailed,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                if (diagnosticInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SelectableText(
                      diagnosticInfo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  child: ConstrainedText(
                    AppLocalizations.of(context)!.audioPlayerRetry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// AudioPlayerToolbarButton — toolbar button for selection actions
// ============================================================================

class AudioPlayerToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const AudioPlayerToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating actions for text selected in the audio player's companion text.
class AudioPlayerSelectionToolbar extends StatelessWidget {
  final String playLabel;
  final String generateLabel;
  final VoidCallback onPlay;
  final VoidCallback onGenerate;

  const AudioPlayerSelectionToolbar({
    super.key,
    required this.playLabel,
    required this.generateLabel,
    required this.onPlay,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 4,
          children: [
            AudioPlayerToolbarButton(
              icon: Icons.play_arrow,
              label: playLabel,
              onPressed: onPlay,
            ),
            AudioPlayerToolbarButton(
              icon: Icons.auto_awesome,
              label: generateLabel,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// buildAudioLoadingView — simple loading indicator
// ============================================================================

Widget buildAudioLoadingView(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.audioPlayerLoading),
      ],
    ),
  );
}
