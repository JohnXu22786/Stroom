import 'package:flutter/material.dart';

import '../providers/provider_config.dart';

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            '播放失败',
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
            child: const Text('重试'),
          ),
        ],
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
              Icon(icon,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// buildAudioLoadingView — simple loading indicator
// ============================================================================

Widget buildAudioLoadingView() {
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在加载音频...'),
      ],
    ),
  );
}
