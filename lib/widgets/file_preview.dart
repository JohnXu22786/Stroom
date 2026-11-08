import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                    maxWidth: isImage ? 64 : 48,
                    maxHeight: isImage ? 52 : 48,
                  ),
                  child: Container(
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
                        ? ExtendedImage.memory(
                            imageBytes!,
                            fit: BoxFit.contain,
                            loadStateChanged: (state) {
                              if (state.extendedImageLoadState ==
                                  LoadState.failed) {
                                return const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.image_outlined, size: 24),
                                );
                              }
                              return null;
                            },
                          )
                        : SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(_fileIcon(),
                                size: 24, color: cs.onSurfaceVariant),
                          ),
                  ),
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
