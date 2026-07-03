import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Full-screen image preview dialog with close and edit buttons.
///
/// Uses [ExtendedImage] (from the `extended_image` package) for built-in
/// pinch-to-zoom, pan, and double-tap zoom gestures — no need for
/// [InteractiveViewer] or a separate image cache.
///
/// For SVG images, uses [SvgPicture.memory] with [InteractiveViewer].
///
/// Parameters:
///   [imageData]   — The image bytes to display. If null or empty,
///                   a "broken image" error state is shown.
///   [fileName]    — Display name shown at the bottom of the screen.
class ImagePreviewDialog extends StatelessWidget {
  final Uint8List? imageData;
  final String fileName;

  const ImagePreviewDialog({
    super.key,
    required this.imageData,
    required this.fileName,
  });

  bool get _isSvg => fileName.toLowerCase().endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(child: _buildContent(context)),
          // Close button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
          ),
          // Edit button (top right) — only for non-SVG
          if (!_isSvg)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 28),
                  tooltip: '编辑图片',
                  onPressed: () => Navigator.pop(context, true),
                ),
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

  Widget _buildContent(BuildContext context) {
    final data = imageData;
    if (data == null || data.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.white54),
            SizedBox(height: 8),
            Text('无法加载图片', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_isSvg) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: SvgPicture.memory(
            data,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox(),
          ),
        ),
      );
    }

    // For non-SVG: use ExtendedImage with gesture mode
    return ExtendedImage.memory(
      data,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.5,
        maxScale: 4.0,
        animationMinScale: 0.5,
        animationMaxScale: 4.0,
        initialScale: 1.0,
        cacheGesture: false,
      ),
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.white54),
                SizedBox(height: 8),
                Text('无法加载图片', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }
        return null;
      },
    );
  }
}
