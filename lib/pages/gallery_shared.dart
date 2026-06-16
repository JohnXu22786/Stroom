import 'package:flutter/material.dart';

Widget buildFormatIcon(String format) {
  return Container(
    color: Colors.grey[200],
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 24, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            format.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    ),
  );
}

String padInt(int n) => n.toString().padLeft(2, '0');
