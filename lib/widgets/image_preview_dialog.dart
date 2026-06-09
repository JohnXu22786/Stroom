import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Full-screen image preview dialog with close and edit buttons.
class ImagePreviewDialog extends StatelessWidget {
  final Uint8List imageData;
  final String fileName;

  const ImagePreviewDialog({
    super.key,
    required this.imageData,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                imageData,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image,
                          size: 48, color: Colors.white54),
                      SizedBox(height: 8),
                      Text('无法加载图片', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Close button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          // Edit button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white, size: 28),
              tooltip: '编辑图片',
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          // Bottom file-name
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
