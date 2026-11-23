import 'package:flutter/material.dart';

/// A safe, localized error message for release-mode rendering failures.
///
/// The scroll view keeps the full guidance reachable when the error slot is
/// shorter than the content, while the minimum viewport height preserves the
/// centered layout when everything fits.
class ReleaseErrorWidget extends StatelessWidget {
  const ReleaseErrorWidget({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E2E),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          );

          if (!constraints.hasBoundedHeight) {
            return content;
          }

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        },
      ),
    );
  }
}
