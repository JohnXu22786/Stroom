import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:stroom/utils/image_manifest.dart' show ImageRecord;
import 'package:stroom/utils/image_thumbnail_loader.dart';

// ====================================================================
// Album Image Thumbnail
// ====================================================================

class AlbumImageThumbnail extends StatefulWidget {
  final ImageRecord record;

  const AlbumImageThumbnail({super.key, required this.record});

  @override
  State<AlbumImageThumbnail> createState() => AlbumImageThumbnailState();
}

class AlbumImageThumbnailState extends State<AlbumImageThumbnail> {
  Future<Uint8List?>? _imageDataFuture;

  @override
  void initState() {
    super.initState();
    _imageDataFuture = ImageThumbnailLoader.loadThumbnail(widget.record);
  }

  @override
  void didUpdateWidget(covariant AlbumImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.hash != oldWidget.record.hash) {
      _imageDataFuture = ImageThumbnailLoader.loadThumbnail(widget.record);
    }
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
        return ExtendedImage.memory(
          data,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // 仅限宽 ≤256px 解码：同时限宽限高会把非正方形图片
          // 压成正方形再裁剪，导致缩略图变形
          cacheWidth: 256,
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.failed) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
                ),
              );
            }
            return null;
          },
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
  final VoidCallback? onTap;

  const AlbumPreviewChip({
    super.key,
    required this.fileName,
    required this.bytes,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              child: ExtendedImage.memory(
                bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return Icon(
                      Icons.image,
                      size: 24,
                      color: cs.onSurfaceVariant,
                    );
                  }
                  return null;
                },
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
      ),
    );
  }
}
