import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

/// Full-screen dark dialog with pinch-to-zoom image preview.
///
/// Uses [ExtendedImage.memory] with gesture mode for built-in
/// pinch-to-zoom, pan, and double-tap zoom — no separate cache needed.
void showImagePreviewDialog({
  required BuildContext context,
  required String fileName,
  required Uint8List data,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: data.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            size: 48, color: Colors.white54),
                        SizedBox(height: 8),
                        Text('无法加载图片',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ExtendedImage.memory(
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
                              Icon(Icons.broken_image,
                                  size: 48, color: Colors.white54),
                              SizedBox(height: 8),
                              Text('无法加载图片',
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        );
                      }
                      return null;
                    },
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
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
    ),
  );
}
