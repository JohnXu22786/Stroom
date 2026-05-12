import 'package:flutter/material.dart';

/// A circular avatar showing the first letter of a name.
///
/// Claude style: h-9 w-9 rounded-full
/// - User: 'U' with gray background
/// - Assistant: 'S' (Stroom) with primary color background
class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = 36,
  });

  bool get _isAssistant {
    final c = name.toUpperCase();
    return c == 'A' || c == 'S';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final Color bgColor;
    final Color textColor;
    if (_isAssistant) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
    } else {
      bgColor = cs.surfaceContainerHighest;
      textColor = cs.onSurfaceVariant;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
