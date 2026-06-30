import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/image_manifest.dart';

// ====================================================================
// Album Image Thumbnail
// ====================================================================

class AlbumImageThumbnail extends StatefulWidget {
  final ImageRecord record;

  const AlbumImageThumbnail({required this.record});

  @override
  State<AlbumImageThumbnail> createState() => AlbumImageThumbnailState();
}

class AlbumImageThumbnailState extends State<AlbumImageThumbnail> {
  Future<Uint8List?>? _imageDataFuture;

  @override
  void initState() {
    super.initState();
    _imageDataFuture = _loadImageData();
  }

  @override
  void didUpdateWidget(covariant AlbumImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.hash != oldWidget.record.hash) {
      _imageDataFuture = _loadImageData();
    }
  }

  Future<Uint8List?> _loadImageData() async {
    // Try reading thumbnail file from disk first
    final thumb =
        await ImageManifest.readFile('${widget.record.hash}_thumb.png');
    if (thumb != null && thumb.isNotEmpty) return thumb;
    // Fall back to full image
    return ImageManifest.readFile(widget.record.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image, color: Colors.grey, size: 24),
            ),
          );
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
            ),
          ),
        );
      },
    );
  }
}

// ====================================================================
// Preview Chip (same style as app_file_picker_dialog)
// ====================================================================

class AlbumPreviewChip extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;
  final VoidCallback onRemove;

  const AlbumPreviewChip({
    required this.fileName,
    required this.bytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 72,
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
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image,
                size: 24,
                color: cs.onSurfaceVariant,
              ),
            ),
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
}
