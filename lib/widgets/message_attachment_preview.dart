import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/attachment_storage.dart';
import '../utils/format_file_size.dart';

/// A larger, clickable attachment preview chip for sent messages.
///
/// Shows a thumbnail for images (loaded async from storage) or a
/// file-type icon for other files, along with the file name and size.
/// Tapping the chip triggers [onTap] to open the full preview.
class MessageAttachmentPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onTap;

  const MessageAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
  });

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

  String _displayName() {
    final name = attachment.fileName;
    if (name.length > 16) {
      return '${name.substring(0, 14)}…';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.fileType == 'image';
    final cs = Theme.of(context).colorScheme;
    final thumbnailSize = 80.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail / icon area
            Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: isImage
                  ? _ImageThumbnail(
                      storagePath: attachment.storagePath,
                      fileIcon: _fileIcon(),
                    )
                  : Icon(
                      _fileIcon(),
                      size: 36,
                      color: cs.onSurfaceVariant,
                    ),
            ),
            const SizedBox(height: 4),
            // File name
            Text(
              _displayName(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            // File size
            Text(
              formatFileSize(attachment.fileSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget that loads and displays an image thumbnail from storage.
/// Uses StatefulWidget to cache the async future and avoid flickering on rebuild.
class _ImageThumbnail extends StatefulWidget {
  final String storagePath;
  final IconData fileIcon;

  const _ImageThumbnail({
    required this.storagePath,
    required this.fileIcon,
  });

  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  late final Future<Uint8List?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = AttachmentStorage.readFile(widget.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.done &&
            snap.hasData &&
            snap.data != null) {
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            width: 80,
            height: 80,
            errorBuilder: (_, __, ___) => Icon(
              widget.fileIcon,
              size: 36,
              color: cs.onSurfaceVariant,
            ),
          );
        }
        return Icon(
          widget.fileIcon,
          size: 36,
          color: cs.onSurfaceVariant,
        );
      },
    );
  }
}
