import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:stroom/utils/file_record.dart';

// ====================================================================
// Tab type identifiers
// ====================================================================

enum FileTabType { text, image, video, audio }

// ====================================================================
// File Picker Tab data holder
// ====================================================================

/// Holds the loaded records and folders for one tab.
class TabData {
  final List<FileRecord> records;
  final Set<String> allFolders;

  TabData({
    required this.records,
    required this.allFolders,
  });
}

// ====================================================================
// Utilities
// ====================================================================

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool isImageFileByExtension(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);
}

// ====================================================================
// Preview Chip widget
// ====================================================================

class PreviewChip extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;
  final bool isImage;
  final VoidCallback onRemove;

  const PreviewChip({
    required this.fileName,
    required this.bytes,
    required this.isImage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: isImage ? 72 : 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? ExtendedImage.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadStateChanged: (state) {
                      if (state.extendedImageLoadState == LoadState.failed) {
                        return _buildFallback(cs);
                      }
                      return null;
                    },
                  )
                : _buildFileChipContent(cs),
          ),
          // Remove button
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: cs.onError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(ColorScheme cs) {
    return Icon(Icons.image, size: 24, color: cs.onSurfaceVariant);
  }

  Widget _buildFileChipContent(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
