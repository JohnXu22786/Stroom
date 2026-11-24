import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_view/photo_view.dart';

import '../utils/byte_lru_cache.dart';
import '../utils/content_hash_save_lock.dart';
import '../utils/file_picker_utils.dart';
import '../utils/image_manifest.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/storage_file_publication.dart';
import 'extended_image_editor_page.dart';
import 'image_editor_page.dart';

import '../widgets/constrained_text.dart';

final ContentHashSaveLock _galleryVisibleNameLocks = ContentHashSaveLock();

/// Serializes Gallery name allocation for export-equivalent folders.
Future<T> withGalleryVisibleNameLock<T>(
  String folder,
  Future<T> Function() action,
) =>
    withGalleryVisibleNameLocks([folder], action);

/// Holds the folder publication lock before callers acquire content-hash locks.
Future<T> withGalleryVisibleNameAndFolderReadLock<T>(
  String folder,
  Future<T> Function() action,
) =>
    withGalleryVisibleNameLock(
      folder,
      () => ImageManifest.withFolderReadLock(folder, action),
    );

Iterable<String> _galleryVisibleNameLockKeys(String folder) sync* {
  final normalized = userVisibleExportPathComparisonKey(folder);
  yield 'gallery-visible-name:';
  var current = '';
  for (final part in normalized.split('/').where((part) => part.isNotEmpty)) {
    current = current.isEmpty ? part : '$current/$part';
    yield 'gallery-visible-name:$current';
  }
}

/// Serializes Gallery path mutations across every folder they can affect.
Future<T> withGalleryVisibleNameLocks<T>(
  Iterable<String> folders,
  Future<T> Function() action,
) =>
    _galleryVisibleNameLocks.withLocks(
      folders.expand(_galleryVisibleNameLockKeys),
      action,
    );

String galleryRecordVisiblePath(ImageRecord record) => record.folder.isEmpty
    ? '${record.name}.${record.format}'
    : '${record.folder}/${record.name}.${record.format}';

/// Whether [path] overlaps an existing visible file or folder path.
bool galleryVisiblePathHasConflict({
  required String path,
  required bool isFolder,
  required Iterable<ImageRecord> records,
  required Iterable<String> folders,
  bool allowExistingFolderDescendants = false,
  Set<String> excludedRecordIds = const {},
  Set<String> excludedFolderPaths = const {},
}) {
  final pathKey = userVisibleExportPathComparisonKey(path);

  for (final record in records) {
    if (excludedRecordIds.contains(record.id)) continue;
    final recordKey = userVisibleExportPathComparisonKey(
      galleryRecordVisiblePath(record),
    );
    if (isFolder
        ? recordKey == pathKey || pathKey.startsWith('$recordKey/')
        : recordKey == pathKey || recordKey.startsWith('$pathKey/')) {
      return true;
    }
  }
  for (final folder in folders) {
    if (excludedFolderPaths.contains(folder)) continue;
    final folderKey = userVisibleExportPathComparisonKey(folder);
    if (isFolder
        ? folderKey == pathKey ||
            (!allowExistingFolderDescendants &&
                folderKey.startsWith('$pathKey/'))
        : folderKey == pathKey || folderKey.startsWith('$pathKey/')) {
      return true;
    }
  }
  return false;
}

/// Finds a free Gallery filename, preserving [baseName] when available.
String uniqueGalleryVisibleName({
  required Iterable<ImageRecord> records,
  required String folder,
  required String baseName,
  required String format,
  Iterable<String> existingFolders = const [],
  Iterable<String> reservedFileNames = const [],
}) {
  String visiblePath(String folderPath, String fileName) =>
      folderPath.isEmpty ? fileName : '$folderPath/$fileName';

  final folderKey = userVisibleExportPathComparisonKey(folder);
  final existingPaths = records
      .where(
        (record) =>
            userVisibleExportPathComparisonKey(record.folder) == folderKey,
      )
      .map(
        (record) => userVisibleExportPathComparisonKey(
          visiblePath(folder, '${record.name}.${record.format}'),
        ),
      )
      .toSet();
  final reservedPaths = reservedFileNames
      .map(
        (fileName) =>
            userVisibleExportPathComparisonKey(visiblePath(folder, fileName)),
      )
      .toSet();

  var suffix = 1;
  while (true) {
    final name = suffix == 1 ? baseName : '$baseName ($suffix)';
    final pathKey = userVisibleExportPathComparisonKey(
      visiblePath(folder, '$name.$format'),
    );
    final conflictsWithFolder = existingFolders.any((existingFolder) {
      final folderPathKey = userVisibleExportPathComparisonKey(existingFolder);
      return folderPathKey == pathKey || folderPathKey.startsWith('$pathKey/');
    });
    if (!existingPaths.contains(pathKey) &&
        !reservedPaths.contains(pathKey) &&
        !conflictsWithFolder) {
      return name;
    }
    suffix++;
  }
}

/// Finds a free Save As name while preserving the historical first-copy name.
String uniqueGallerySaveAsName({
  required Iterable<ImageRecord> records,
  required String folder,
  required String sourceName,
  required String format,
  Iterable<String> existingFolders = const [],
}) =>
    uniqueGalleryVisibleName(
      records: records,
      folder: folder,
      baseName: '${sourceName}_edited',
      format: format,
      existingFolders: existingFolders,
    );

/// Adds a Gallery folder only when its export path is free of file collisions.
///
/// Folder creation shares the parent folder's visible-name lock with imports
/// and Save As so a root file and a same-named folder cannot be published from
/// stale snapshots.
Future<bool> createGalleryFolderIfNameAvailable(
  String folderPath,
  Future<void> Function() createFolder,
) async {
  final parentFolder = ImageManifest.getParentFolderPath(folderPath);
  return withGalleryVisibleNameLock(parentFolder, () async {
    final records = await ImageManifest.loadRecordsStrict();
    final existingFolders = await ImageManifest.getAllFolders();
    if (galleryVisiblePathHasConflict(
      path: folderPath,
      isFolder: true,
      records: records,
      folders: existingFolders,
      allowExistingFolderDescendants: true,
    )) {
      return false;
    }

    await createFolder();
    return true;
  });
}

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
      // enableLoadState 默认 false：若 loadStateChanged 的 loading 分支被
      // 误删返回 null，页面会黑屏而不是显示默认加载圈 —— 打开开关兜底
      enableLoadState: true,
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
          return _buildErrorWidget(
            AppLocalizations.of(context)!.imagePreviewLoadFailed,
          );
        }
        // 全分辨率解码完成前统一显示加载圈，不显示缩略图 —— 进入查看器时
        // 先看到的是加载动画，而不是低分辨率的缩略图占位
        if (state.extendedImageLoadState == LoadState.loading) {
          return _buildLoadingPlaceholder();
        }
        return null;
      },
    );
  }

  /// 加载占位：全图字节读取/解码完成前统一显示加载圈，不显示缩略图。
  Widget _buildLoadingPlaceholder() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
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
        MaterialPageRoute(builder: (_) => ImageEditorPage(imageBytes: bytes)),
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
      late ImageRecord newRecord;
      Future<void> save() => ImageManifest.withSaveLocks(
            [newHash, file.hash],
            () => publishStorageFiles<void, ImageRecord>(
              publish: (writeFile) async {
                await writeFile(newFileName, editedBytes);
                if (isSaveAs) {
                  final existingRecords =
                      await ImageManifest.loadRecordsStrict();
                  final existingFolders = await ImageManifest.getAllFolders();
                  newRecord = ImageRecord(
                    name: uniqueGallerySaveAsName(
                      records: existingRecords,
                      folder: file.folder,
                      sourceName: file.name,
                      format: file.format,
                      existingFolders: existingFolders,
                    ),
                    hash: newHash,
                    format: file.format,
                    createdAt: DateTime.now(),
                    size: editedBytes.length,
                    folder: file.folder,
                  );
                  await ImageManifest.addRecord(newRecord);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!
                              .imageViewerImageSavedAsCopy,
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  newRecord = ImageRecord(
                    name: file.name,
                    hash: newHash,
                    format: file.format,
                    createdAt: file.createdAt,
                    size: editedBytes.length,
                    folder: file.folder,
                  );
                  await ImageManifest.addRecord(newRecord);
                  await ImageManifest.deleteRecord(file.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.imageViewerImageUpdated,
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              loadRecords: ImageManifest.loadRecordsStrict,
              isReferenced: (record, name) =>
                  record.hash == newHash &&
                  (name == record.storageFileName ||
                      name == imageThumbFileName(record.hash)),
              writeFile: ImageManifest.writeFile,
              readFile: ImageManifest.readFile,
              fileExists: ImageManifest.fileExists,
              deleteFile: ImageManifest.deleteFile,
            ),
          );
      await withGalleryVisibleNameAndFolderReadLock(file.folder, save);

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
            content: Text(
              AppLocalizations.of(context)!.imageViewerSaveFailed(e.toString()),
            ),
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
                return Center(
                  child: Text(
                    AppLocalizations.of(context)!.imageViewerInvalidIndex,
                  ),
                );
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
                    return _buildLoadingPlaceholder();
                  }
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) {
                    return _buildErrorWidget(
                      AppLocalizations.of(context)!.imagePreviewLoadFailed,
                    );
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
                      icon: const Icon(
                        Icons.crop,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: AppLocalizations.of(context)!.imagePreviewCrop,
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
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: AppLocalizations.of(context)!.imagePreviewEdit,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
            child: ConstrainedText(
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
