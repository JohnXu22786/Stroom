import 'package:flutter/material.dart';

import 'constrained_text.dart';

/// Dialog heading that keeps the error icon and dismiss control visible when a
/// localized title is clipped by a narrow viewport or large text scale.
class ErrorDetailDialogHeader extends StatelessWidget {
  const ErrorDetailDialogHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedText(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
