import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_view/photo_view.dart';

import '../utils/byte_lru_cache.dart';
import '../utils/image_manifest.dart';
import '../utils/image_thumbnail_loader.dart';
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

  /// 原图字节 LRU 缓存（按总字节数设上限，防止浏览大量大图时内存暴涨）。
  final ByteLruCache _bytesCache = ByteLruCache(maxBytes: 48 * 1024 * 1024);

  /// 进行中的磁盘读取（按 record id 去重，完成后即移除 —
  /// 已完成的结果由 [_bytesCache] 持有，避免 Future 无限保留大图引用）。
  final Map<String, Future<Uint8List?>> _bytesFutures = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = ExtendedPageController(initialPage: _currentIndex);
    // 预加载相邻页字节：滑到下一页时磁盘读取已完成，只剩解码
    _preloadNeighbors(_currentIndex);
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

  // ---- 字节缓存 ----------------------------------------------------------

  Future<Uint8List?> _readImageBytes(ImageRecord record) {
    // 缓存命中：同步返回（LRU touch）
    final cached = _bytesCache.get(record.id);
    if (cached != null) {
      return Future.value(cached);
    }
    // 去重：同一张图的并发读取共享同一个 Future
    final inflight = _bytesFutures[record.id];
    if (inflight != null) return inflight;
    late final Future<Uint8List?> future;
    future = () async {
      try {
        final bytes = await ImageManifest.readFile(record.storagePath);
        // 读取期间记录被编辑/删除（_bytesFutures 已清空）时不再
        // 重新插入过期字节，避免死缓存占用内存
        if (bytes != null &&
            bytes.isNotEmpty &&
            _bytesFutures[record.id] == future) {
          _bytesCache.put(record.id, bytes);
        }
        return bytes;
      } finally {
        // 身份守卫：读取期间记录被编辑/删除后同 id 可能注册了新的
        // Future，不能把它一并移除
        if (_bytesFutures[record.id] == future) {
          _bytesFutures.remove(record.id);
        }
      }
    }();
    _bytesFutures[record.id] = future;
    return future;
  }

  /// 预加载 [index] 相邻页的原图字节（只触发磁盘读取，不构建页面）。
  void _preloadNeighbors(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= widget.images.length) continue;
      final record = widget.images[i];
      // 超大图（单张超过缓存上限的 1/3）预加载会被 LRU 自己挤出，
      // 预加载毫无收益还白白多一次读盘 → 跳过，翻页时按需读取
      if (record.size > _bytesCache.maxBytes ~/ 3) continue;
      _readImageBytes(record);
    }
  }

  // ---- 页面构建 ----------------------------------------------------------

  Widget _buildImagePageContent(ImageRecord record, Uint8List bytes) {
    final isSvg = record.format.toLowerCase() == 'svg';
    if (isSvg) {
      return _buildSvgPage(bytes);
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
        // 全分辨率解码期间继续显示缩略图，避免缩略图 → 白色加载圈 → 全图
        // 的两次切换闪烁
        if (state.extendedImageLoadState == LoadState.loading) {
          final thumb = ImageThumbnailLoader.peek(record);
          if (thumb != null) {
            return _buildThumbnailPlaceholder(thumb);
          }
        }
        return null;
      },
    );
  }

  /// 加载占位：只显示已缓存/已加载的缩略图，绝不触发新的缩略图生成。
  /// 全图字节的读取始终已在进行（itemBuilder 的 FutureBuilder 与
  /// 预加载），占位符再走一次 loadThumbnail 会重复读取同一张原图。
  Widget _buildLoadingPlaceholder(ImageRecord record) {
    final cachedThumb = ImageThumbnailLoader.peek(record);
    if (cachedThumb != null) {
      return _buildThumbnailPlaceholder(cachedThumb);
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildThumbnailPlaceholder(Uint8List thumb) {
    return Center(
      child: Image.memory(
        thumb,
        fit: BoxFit.contain,
        // 256px 缩略图放大到全屏时用中等过滤，减少明显锯齿
        filterQuality: FilterQuality.medium,
      ),
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

      // The quick editor processes the image in place (the page stays
      // open with a spinner until the pipeline finishes) and pops back
      // with the edited bytes.
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
      _bytesCache.put(newRecord.id, editedBytes);
      _bytesCache.remove(file.id);
      _bytesFutures.remove(file.id);

      // 覆盖保存删除了旧记录：丢弃旧 hash 的缩略图内存缓存。
      // （saveAs 分支保留旧记录，旧缩略图继续有效，无需处理。）
      if (!isSaveAs) {
        ImageThumbnailLoader.invalidate(file.hash);
      }

      // 后台生成新图的缩略图并持久化：返回相册网格时直接命中，
      // 不再走"读原图 + 全分辨率解码"的回退路径
      unawaited(ImageThumbnailLoader.loadThumbnail(newRecord));

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
              // 预加载下一页/上一页的字节，翻页只等解码不等读盘
              _preloadNeighbors(index);
            },
            itemBuilder: (context, index) {
              if (index < 0 || index >= widget.images.length) {
                return const Center(child: Text('Invalid index'));
              }
              final record = widget.images[index];
              // 字节已缓存：同步构建页面，避免 FutureBuilder 闪加载态
              final cached = _bytesCache.get(record.id);
              if (cached != null) {
                return _buildImagePageContent(record, cached);
              }
              return FutureBuilder<Uint8List?>(
                future: _readImageBytes(record),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingPlaceholder(record);
                  }
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) {
                    return _buildErrorWidget('Cannot load image');
                  }
                  return _buildImagePageContent(record, bytes);
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
