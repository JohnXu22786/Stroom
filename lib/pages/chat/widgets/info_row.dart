import 'package:flutter/material.dart';
import 'package:stroom/utils/text_breaks.dart';

/// A simple info row label: value pair used in file info preview dialogs.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = TextStyle(fontSize: 13, color: cs.onSurface);
              final effectiveStyle =
                  DefaultTextStyle.of(context).style.merge(style);
              final displayValue = breakOverlongWords(
                value,
                maxWidth: constraints.maxWidth,
                style: effectiveStyle,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              );
              return Text(displayValue, semanticsLabel: value, style: style);
            },
          ),
        ),
      ],
    );
  }
}
