import 'package:flutter/material.dart';

/// A simple info row label: value pair used in file info preview dialogs.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayValue = value.characters.join('\u200B');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            semanticsLabel: value,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
