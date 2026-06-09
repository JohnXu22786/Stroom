import 'package:flutter/material.dart';

import '../../models/assistant.dart';

/// A widget that displays the assistant's avatar.
///
/// Supports two avatar types:
/// - `emoji`: renders the [Assistant.emoji] string as large text in a rounded container
/// - `image`: renders [Assistant.avatarUrl] via [Image.network] in a rounded container
///
/// Falls back to emoji mode when [Assistant.avatarType] is 'emoji' or not set.
class AssistantAvatar extends StatelessWidget {
  final Assistant assistant;
  final double size;
  final double borderRadius;

  const AssistantAvatar({
    super.key,
    required this.assistant,
    this.size = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isImage = assistant.avatarType == 'image' &&
        assistant.avatarUrl != null &&
        assistant.avatarUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: isImage
          ? Image.network(
              assistant.avatarUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackEmoji(cs),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            )
          : _buildFallbackEmoji(cs),
    );
  }

  Widget _buildFallbackEmoji(ColorScheme cs) {
    return Center(
      child: Text(
        assistant.emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
