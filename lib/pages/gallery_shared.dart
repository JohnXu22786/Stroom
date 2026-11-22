import 'package:flutter/material.dart';

import '../widgets/constrained_text.dart';

Widget buildFormatIcon(String format) {
  return Container(
    color: Colors.grey[200],
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 24, color: Colors.grey),
          const SizedBox(height: 4),
          ConstrainedText(
            format.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

String padInt(int n) => n.toString().padLeft(2, '0');
