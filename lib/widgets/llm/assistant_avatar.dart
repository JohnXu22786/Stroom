import 'package:flutter/material.dart';

import '../../models/assistant.dart';

/// A widget that displays the assistant's avatar.
///
/// Renders [Assistant.emoji] as large text in a rounded container.
/// Image avatar support has been removed — only emoji avatars are supported.
///
/// On narrow screens the emoji text is wrapped in [FittedBox] so that it scales
/// down to fit the container instead of overflowing.
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            assistant.emoji,
            style: TextStyle(fontSize: size * 0.5),
          ),
        ),
      ),
    );
  }
}
