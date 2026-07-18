import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_view/photo_view.dart';

import '../utils/image_manifest.dart';
import 'extended_image_editor_page.dart';
import 'image_editor_page.dart';

/// Full-screen gallery viewer with paging support.
class GalleryViewerPage extends StatefulWidget {
  final List<ImageRecord> images;
  final int initialIndex;

  const GalleryViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late ExtendedPageController _pageController;
  late int _currentIndex;

  bool _isLoading = false;
  final Map<String, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = ExtendedPageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentFileName {
    final rec = widget.images[_currentIndex];
    return '${rec.name}.${rec.format}';
  }

  bool get _isCurrentSvg {
    return widget.images[_currentIndex].format.toLowerCase() == 'svg';
  }

  Future<Uint8List?> _readImageBytes(ImageRecord record) async {
    final cached = _imageCache[record.id];
    if (cached != null) return cached;
    final bytes = await ImageManifest.readFile(record.storagePath);
    _imageCache[record.id] = bytes;
    return bytes;
  }

  Future<Widget> _buildImagePage(int index) async {
    if (index < 0 || index >= widget.images.length) {
      return const Center(child: Text('Invalid index'));
    }

    final record = widget.images[index];
    final isSvg = record.format.toLowerCase() == 'svg';

    if (isSvg) {
      final bytes = await _readImageBytes(record);
      if (bytes == null || bytes.isEmpty) {
        return _buildErrorWidget('Cannot load SVG');
      }
      return _buildSvgPage(bytes);
    }

    final bytes = await _readImageBytes(record);
    if (bytes == null || bytes.isEmpty) {
      return _buildErrorWidget('Cannot load image');
    }
    return ExtendedImage.memory(
      bytes,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.5,
        maxScale: 6.0,
        animationMinScale: 0.5,
        animationMaxScale: 6.0,
        initialScale: 1.0,
        cacheGesture: false,
        inPageView: true,
      ),
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return _buildErrorWidget('Cannot load image');
        }
        return null;
      },
    );
  }

  Widget _buildSvgPage(Uint8List bytes) {
    return PhotoView.customChild(
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      child: SvgPicture.memory(bytes, fit: BoxFit.contain),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Future<void> _onCrop() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final record = widget.images[_currentIndex];
      final bytes = await _readImageBytes(record);
      if (bytes == null || bytes.isEmpty || !mounted) return;

      final editedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtendedImageEditorPage(
            imageBytes: bytes,
            fileName: '${record.name}.${record.format}',
          ),
        ),
      );

      if (editedBytes == null || !mounted) return;

      // Show the same save dialog as the full editor uses.
      final saveAction = await showImageSaveDialog(context);
      if (!mounted) return;
      if (saveAction == null || saveAction == SaveAction.cancel) return;

      await _saveEditedImage(
        record,
        editedBytes,
        isSaveAs: saveAction == SaveAction.saveAs,
      );
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _onEdit() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final record = widget.images[_currentIndex];
      final bytes = await _readImageBytes(record);
      if (bytes == null || bytes.isEmpty || !mounted) return;

      final result = await Navigator.push<ImageEditorResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorPage(imageBytes: bytes),
        ),
      );

      if (result != null && mounted) {
        await _saveEditedImage(
          record,
          result.editedBytes,
          isSaveAs: result.isSaveAs,
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _saveEditedImage(
    ImageRecord file,
    Uint8List editedBytes, {
    required bool isSaveAs,
  }) async {
    try {
      final newHash = computeImageHash(editedBytes);
      final newFileName = '$newHash.${file.format}';
      await ImageManifest.writeFile(newFileName, editedBytes);

      ImageRecord newRecord;

      if (isSaveAs) {
        newRecord = ImageRecord(
          name: '${file.name}_edited',
          hash: newHash,
          format: file.format,
          createdAt: DateTime.now(),
          size: editedBytes.length,
          folder: file.folder,
        );
        await ImageManifest.addRecord(newRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved as copy'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await ImageManifest.deleteFile(file.storagePath);
        await ImageManifest.deleteRecord(file.id);
        newRecord = ImageRecord(
          name: file.name,
          hash: newHash,
          format: file.format,
          createdAt: file.createdAt,
          size: editedBytes.length,
          folder: file.folder,
        );
        await ImageManifest.addRecord(newRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image updated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Update in-memory cache and widget data so the current page shows
      // the new image immediately without requiring a manual refresh.
      // Insert new cache entry before removing the old one to avoid a
      // narrow window where a rebuild could attempt to read the deleted
      // file from disk.
      _imageCache[newRecord.id] = editedBytes;
      _imageCache.remove(file.id);

      // Update the record in-place. The parent always passes a mutable
      // list (gallery_page.dart line 155 — folderImages.toList()), so
      // this is safe. Without this update the current page would still
      // reference the old record ID and fail to display.
      final idx = widget.images.indexWhere((r) => r.id == file.id);
      if (idx >= 0) {
        widget.images[idx] = newRecord;
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ExtendedImageGesturePageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return FutureBuilder<Widget>(
                future: _buildImagePage(index),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return _buildErrorWidget('Load failed');
                  }
                  return snapshot.data!;
                },
              );
            },
          ),

          // Close button
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Crop + Edit buttons (non-SVG only)
          if (!_isCurrentSvg)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.crop, color: Colors.white, size: 24),
                      tooltip: 'Crop',
                      onPressed: _onCrop,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, color: Colors.white, size: 24),
                      tooltip: 'Edit',
                      onPressed: _onEdit,
                    ),
                  ),
                ],
              ),
            ),

          // Page indicator
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // File name
          Positioned(
            bottom: 52,
            left: 16,
            right: 16,
            child: Text(
              _currentFileName,
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
