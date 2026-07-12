import 'package:flutter/material.dart';

enum LineStatus { newVoice, duplicate, formatError }

class ParsedLine {
  final int index;
  final String name;
  final String id;
  final LineStatus status;
  final String? errorMsg;

  ParsedLine({
    required this.index,
    required this.name,
    required this.id,
    required this.status,
    this.errorMsg,
  });
}

class VbTableCell extends StatelessWidget {
  final String text;
  final bool isHeader;

  const VbTableCell(this.text, {super.key, this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : null,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }
}
