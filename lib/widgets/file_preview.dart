import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class FilePreviewChip extends StatelessWidget {
  final Attachment attachment;
  final Uint8List? imageBytes;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const FilePreviewChip({
    super.key,
    required this.attachment,
    this.imageBytes,
    this.onRemove,
    this.onTap,
  });

  String _displayName() {
    final name = attachment.fileName;
    if (name.length > 16) {
      return '${name.substring(0, 14)}…';
    }
    return name;
  }

  IconData _fileIcon() {
    switch (attachment.fileType) {
      case 'image':
        return Icons.image_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'document':
        return Icons.insert_drive_file_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.fileType == 'image' && imageBytes != null;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isImage
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) =>
                              Icon(_fileIcon(), size: 24),
                        )
                      : Icon(_fileIcon(),
                          size: 24, color: cs.onSurfaceVariant),
                ),
                if (onRemove != null)
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
            const SizedBox(height: 2),
            Text(
              _displayName(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
