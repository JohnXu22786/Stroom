import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_platform_video_thumbnails/cross_platform_video_thumbnails.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;

import '../providers/video_provider.dart';
import 'video_gallery_shared.dart';
import '../utils/video_manifest.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../utils/manifest_bridge.dart';
import '../widgets/file_manager_view.dart';
import '../widgets/file_manager_utils.dart';
import 'files_page_shared.dart';

class VideoGalleryPage extends ConsumerStatefulWidget {
  final int tabIndex;
  final bool isActiveTab;

  const VideoGalleryPage(
      {super.key, this.tabIndex = 0, this.isActiveTab = true});

  @override
  ConsumerState<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends ConsumerState<VideoGalleryPage> {
  /// Shared futures for thumbnail generation — when multiple [FutureBuilder]s
  /// fire for the same hash, they all await the same future instead of one
  /// proceeding and the others returning `null` permanently.
  final Map<String, Future<Uint8List?>> _thumbnailFutures = {};

  /// Lazy initialization guard for [CrossPlatformVideoThumbnails].
  bool _thumbnailInitialized = false;
  Completer<void>? _initCompleter;

  Future<void> _ensureThumbnailInitialized() async {
    if (_thumbnailInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      await CrossPlatformVideoThumbnails.initialize();
      _thumbnailInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null; // Allow retry on failure
      rethrow;
    }
  }

  /// Probe video duration using VideoPlayerController (backed by fvp).
  /// This is separate from thumbnail generation.
  Future<int> _probeVideoDuration(String videoPath) async {
    if (kIsWeb) return 0;
    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds;
      await controller.dispose();
      return duration;
    } catch (_) {
      await controller.dispose();
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoRecordsProvider.notifier).loadRecords();
      ref.read(videoFolderListProvider.notifier).loadFolders();
    });
    // 重新进入文件页（切换底部导航）时 filesRefreshSignalProvider 递增：
    // 只重载数据，不重建页面，保留已打开的文件夹层级。
    ref.listenManual(filesRefreshSignalProvider, (prev, next) {
      ref.read(videoRecordsProvider.notifier).loadRecords();
      ref.read(videoFolderListProvider.notifier).loadFolders();
    });
  }

  @override
  void dispose() {
    _thumbnailFutures.clear();
    super.dispose();
  }

  /// Tracks the currently-active folder (synced from FileManagerView).
  String _currentFolder = '';

  /// Guards against re-entrant imports.
  bool _isImporting = false;

  /// Generate a unique file-name for the currently-active folder.
  String _uniqueVideoName(
    String baseName,
    List<VideoRecord> records,
    Set<String> usedInBatch,
  ) {
    bool taken(String name) =>
        usedInBatch.contains(name) ||
        records.any((r) => r.name == name && r.folder == _currentFolder);
    if (!taken(baseName)) return baseName;
    int i = 2;
    while (taken('$baseName ($i)')) {
      i++;
    }
    return '$baseName ($i)';
  }

  // ====================================================================
  // Record / Import
  // ====================================================================

  Future<void> _recordVideo() async {
    // 直接保存到当前正在浏览的文件夹（_currentFolder），不再弹文件夹选择
    // 记录加载对话框是否弹出：异常发生在弹窗之前（如系统相机抛错）
    // 或成功弹出之后（如 loadRecords 抛错）时，catch 中的 pop 会误弹
    // 下层路由（应用根路由），因此必须带条件执行
    var dialogShown = false;
    var videoSaved = false;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.camera);
      if (pickedFile == null) return;
      if (!mounted) return;

      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        // PopScope(canPop: false)：barrierDismissible 只能拦截点击遮罩，
        // 系统返回键仍会关掉对话框 —— 若不拦截，加载完成后
        // Navigator.pop() 可能误弹下层路由（应用根路由）
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
      dialogShown = true;

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isNotEmpty) {
        final hash = computeVideoHash(bytes);
        final rawName = sanitizeFileName(pickedFile.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'mp4';
        final storageFileName = '$hash.$format';

        final records = ref.read(videoRecordsProvider);
        final displayName = _uniqueVideoName(
          p.basenameWithoutExtension(rawName),
          records,
          <String>{},
        );

        await VideoManifest.writeFile(storageFileName, bytes);
        // Try to obtain video duration and thumbnail from the file
        int videoDurationMs = 0;
        final videoPath = await VideoManifest.readFilePath(storageFileName);
        if (videoPath != null && videoPath.isNotEmpty) {
          try {
            videoDurationMs = await _probeVideoDuration(videoPath);
            final thumbBytes = await _generateThumbnailFromPath(videoPath);
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(hash, thumbBytes);
            }
          } catch (_) {
            // Duration/thumbnail detection failed
          }
        }
        if (videoPath == null || videoPath.isEmpty) {
          // Fallback: try from bytes (e.g., web without direct path)
          try {
            final thumbBytes = await _generateThumbnailFromBytes(bytes);
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(hash, thumbBytes);
            }
          } catch (_) {}
        }
        await VideoManifest.addRecord(
          VideoRecord(
            name: displayName,
            hash: hash,
            format: format,
            createdAt: DateTime.now(),
            size: bytes.length,
            folder: _currentFolder,
            duration: videoDurationMs,
          ),
        );
        videoSaved = true;
      }

      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      await ref.read(videoRecordsProvider.notifier).loadRecords();
      await ref.read(videoFolderListProvider.notifier).loadFolders();
      // 只有真正保存了记录才提示成功（空字节时没有保存任何内容）
      if (mounted && videoSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('视频已保存'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && dialogShown) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('录制失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importFromGallery() async {
    if (_isImporting) return;
    _isImporting = true;
    // 记录加载对话框是否弹出：异常发生在弹窗之前（如文件选择器/系统
    // 相册抛错）或成功弹出之后（如 loadRecords 抛错）时，catch 中的
    // pop 会误弹下层路由（应用根路由），因此必须带条件执行
    var dialogShown = false;
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiVideo();
      if (pickedFiles.isEmpty) {
        _isImporting = false;
        return;
      }

      if (!mounted) return;
      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        // PopScope(canPop: false)：barrierDismissible 只能拦截点击遮罩，
        // 系统返回键仍会关掉对话框 —— 若不拦截，加载完成后
        // Navigator.pop() 可能误弹下层路由（应用根路由）
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
      dialogShown = true;

      final records = ref.read(videoRecordsProvider);
      final usedInBatch = <String>{};
      var count = 0;
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) continue;

        final hash = computeVideoHash(bytes);
        final rawName = sanitizeFileName(pickedFile.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'mp4';
        final storageFileName = '$hash.$format';

        final displayName = _uniqueVideoName(
          p.basenameWithoutExtension(rawName),
          records,
          usedInBatch,
        );
        usedInBatch.add(displayName);

        final videoPath = await VideoManifest.writeFile(
          storageFileName,
          bytes,
        );
        // Try to obtain video duration and thumbnail from the file
        int videoDurationMs = 0;
        if (videoPath.isNotEmpty) {
          try {
            videoDurationMs = await _probeVideoDuration(videoPath);
            final thumbBytes = await _generateThumbnailFromPath(videoPath);
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(hash, thumbBytes);
            }
          } catch (_) {
            // Duration/thumbnail detection failed
          }
        }
        if (videoPath.isEmpty) {
          // Fallback: try from bytes (e.g., web without direct path)
          try {
            final thumbBytes = await _generateThumbnailFromBytes(bytes);
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(hash, thumbBytes);
            }
          } catch (_) {}
        }
        await VideoManifest.addRecord(
          VideoRecord(
            name: displayName,
            hash: hash,
            format: format,
            createdAt: DateTime.now(),
            size: bytes.length,
            folder: _currentFolder,
            duration: videoDurationMs,
          ),
        );
        count++;
      }

      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      await ref.read(videoRecordsProvider.notifier).loadRecords();
      await ref.read(videoFolderListProvider.notifier).loadFolders();
      // 没有任何视频被导入（如全部跳过）时不显示成功提示
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 $count 个视频'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _isImporting = false;
    } catch (e) {
      _isImporting = false;
      if (mounted && dialogShown) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ====================================================================
  // Playback
  // ====================================================================

  Future<void> _playVideo(VideoRecord file) async {
    final filePath = await VideoManifest.readFilePath(file.storagePath);
    if (filePath == null || filePath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法加载视频文件')));
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          filePath: filePath,
          displayName: '${file.name}.${file.format}',
        ),
      ),
    );
  }

  // ====================================================================
  // Export
  // ====================================================================

  Future<void> _exportFile(String id) async {
    try {
      final records = ref.read(videoRecordsProvider);
      final file = records.firstWhere((r) => r.id == id);

      final data = await VideoManifest.readFile(file.storagePath);
      if (data == null || data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('文件数据读取失败')));
        }
        return;
      }

      final exportName = '${file.name}.${file.format}';
      final outputPath = await FilePicker.saveFile(
        dialogTitle: '导出视频',
        fileName: exportName,
        type: FileType.custom,
        allowedExtensions: [file.format],
        bytes: data,
      );
      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出到: $outputPath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 批量导出文件。返回用户最终使用的导出目录
  /// （用户取消目录选择或导出失败时返回 null；Web 端返回 ''）。
  Future<String?> _exportFiles(List<String> ids, String targetDirectory) async {
    try {
      String? outputDir;
      if (kIsWeb) {
        outputDir = '';
      } else {
        outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
        if (outputDir == null) {
          outputDir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
          if (outputDir == null) return null;
        }
      }

      if (!mounted) return null;

      final records = ref.read(videoRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);
        final data = await VideoManifest.readFile(file.storagePath);
        if (data == null || data.isEmpty) continue;

        final exportName = '${file.name}.${file.format}';

        if (kIsWeb) {
          final saved = await FilePicker.saveFile(
            dialogTitle: '导出视频',
            fileName: exportName,
            type: FileType.custom,
            allowedExtensions: [file.format],
            bytes: data,
          );
          // 用户取消保存时不计数
          if (saved == null) continue;
        } else {
          final outputPath = p.join(outputDir, exportName);
          await File(outputPath).writeAsBytes(data);
        }
        exportedCount++;
      }

      // Web 端全部保存被取消时返回 null（与原生端取消目录选择一致，
      // 保持选择模式不退出）
      if (kIsWeb && exportedCount == 0) return null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 $exportedCount 个文件'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return outputDir;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// 批量导出文件夹（保留完整文件夹层级，含子文件夹内容）。
  /// 返回用户最终使用的导出目录（用户取消或失败时返回 null；Web 端返回 ''）。
  Future<String?> _exportFolders(
    List<String> names,
    String targetDirectory,
  ) async {
    try {
      if (kIsWeb) {
        if (!mounted) return null;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('文件夹导出'),
            content: const Text(
              '浏览器暂不支持选择导出目录，你可以逐个导出文件夹内的文件，或使用 App 以获得完整体验。',
            ),
            actions: [
              TextButton(
                key: const Key('fm_web_export_cancel_btn'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                key: const Key('fm_web_export_individual_btn'),
                onPressed: () => Navigator.pop(ctx, 'exportFiles'),
                child: const Text('逐个导出文件'),
              ),
            ],
          ),
        );

        if (action != 'exportFiles' || !mounted) return null;

        final records = ref.read(videoRecordsProvider);
        var exportedCount = 0;
        for (final folderName in names) {
          final folderFiles = records
              .where(
                (r) =>
                    r.folder == folderName ||
                    r.folder.startsWith('$folderName/'),
              )
              .toList();
          for (final file in folderFiles) {
            final data = await VideoManifest.readFile(file.storagePath);
            if (data == null || data.isEmpty) continue;
            final exportName = '${file.name}.${file.format}';
            // 用户取消保存时不计数
            final saved = await FilePicker.saveFile(
              dialogTitle: '导出视频',
              fileName: exportName,
              type: FileType.custom,
              allowedExtensions: [file.format],
              bytes: data,
            );
            if (saved == null) continue;
            exportedCount++;
          }
        }
        // 全部保存被取消时返回 null（保持选择模式不退出），
        // 且不显示「已导出 0 个文件」提示
        if (exportedCount == 0) return null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已导出 $exportedCount 个文件'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return '';
      }

      String? outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
      if (outputDir == null) {
        outputDir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
        if (outputDir == null) return null;
      }

      if (!mounted) return null;

      final records = ref.read(videoRecordsProvider);
      var exportedCount = 0;

      for (final folderName in names) {
        // 包含所有后代文件夹中的文件，完整保留层级
        final folderFiles = records
            .where(
              (r) =>
                  r.folder == folderName || r.folder.startsWith('$folderName/'),
            )
            .toList();

        for (final file in folderFiles) {
          final data = await VideoManifest.readFile(file.storagePath);
          if (data == null || data.isEmpty) continue;

          final exportName = '${file.name}.${file.format}';
          final fileDir = p.join(outputDir, file.folder);
          await Directory(fileDir).create(recursive: true);
          final outputPath = p.join(fileDir, exportName);
          await File(outputPath).writeAsBytes(data);
          exportedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 $exportedCount 个文件'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return outputDir;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  Future<String?> _exportFolder(String folderName) async {
    return _exportFolders([folderName], '');
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(videoRecordsProvider);
    final folders = ref.watch(videoFolderListProvider);
    final sortConfig = ref.watch(videoSortConfigProvider);
    final viewMode = ref.watch(videoViewModeProvider);

    // Sort records
    final sortedRecords = List<VideoRecord>.from(records);
    sortedRecords.sort((a, b) {
      int Function(VideoRecord, VideoRecord) getCmp;
      switch (sortConfig.field) {
        case SortField.createdAt:
          getCmp = (x, y) => x.createdAt.compareTo(y.createdAt);
        case SortField.name:
          getCmp =
              (x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase());
        case SortField.size:
          getCmp = (x, y) => x.size.compareTo(y.size);
      }
      final cmp = getCmp(a, b);
      return sortConfig.order == SortOrder.descending ? -cmp : cmp;
    });

    // Top action bar — available only in the root folder
    final topActionBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _recordVideo,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.videocam, size: 20),
                label: const Text(
                  '录制',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _importFromGallery,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  '导入',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Build file-thumbnail builder — simplified, just a video cam icon
    Widget buildThumbnailFallback(VideoRecord file) {
      return Container(
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Center(
              child: Icon(Icons.videocam, size: 40, color: Colors.red),
            ),
            if (file.duration > 0)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatDuration(file.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    /// Internal — performs the actual thumbnail generation.
    Future<Uint8List?> generateThumbnailForFile(VideoRecord file) async {
      try {
        final videoPath = await VideoManifest.readFilePath(file.storagePath);
        if (videoPath == null || videoPath.isEmpty) {
          // Fallback: read bytes and try from bytes
          final videoBytes = await VideoManifest.readFile(file.storagePath);
          if (videoBytes != null) {
            final thumbBytes = await _generateThumbnailFromBytes(videoBytes);
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(file.hash, thumbBytes);
              return thumbBytes;
            }
          }
          return null;
        }

        final thumbBytes = await _generateThumbnailFromPath(videoPath);
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          await VideoManifest.writeThumbnail(file.hash, thumbBytes);
          return thumbBytes;
        }
      } catch (e) {
        debugPrint('generateThumbnailForFile error for ${file.hash}: $e');
        // Silently fail — fallback to icon will be shown
      }
      return null;
    }

    /// Try to read the cached thumbnail; if missing, generate it on demand.
    /// Uses a shared-future pattern ([_thumbnailFutures]) so that when multiple
    /// [FutureBuilder]s fire simultaneously for the same hash they all await the
    /// same in-progress generation instead of some getting `null` permanently.
    Future<Uint8List?> loadOrGenerateThumbnail(VideoRecord file) async {
      // First try to read the cached thumbnail (fast path — no future needed)
      final existing = await VideoManifest.readThumbnail(file.hash);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }

      // Shared-future guard: if another caller is already working on this hash,
      // await the same future instead of returning null.
      final pending = _thumbnailFutures[file.hash];
      if (pending != null) {
        return pending;
      }

      // Start generation and store the future so siblings can await it.
      final future = generateThumbnailForFile(file);
      _thumbnailFutures[file.hash] = future;

      try {
        return await future;
      } finally {
        _thumbnailFutures.remove(file.hash);
      }
    }

    Widget fileThumbnailBuilder(VideoRecord file) {
      return FutureBuilder<Uint8List?>(
        future: loadOrGenerateThumbnail(file),
        builder: (context, snapshot) {
          final thumbData = snapshot.data;
          if (thumbData != null && thumbData.isNotEmpty) {
            return Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    thumbData,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => buildThumbnailFallback(file),
                  ),
                  if (file.duration > 0)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formatDuration(file.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          return buildThumbnailFallback(file);
        },
      );
    }

    // FileManagerConfig
    final config = FileManagerConfig<VideoRecord>(
      title: '视频',
      topActionBar: topActionBar,
      showThumbnailToggle: true,
      fileIconBuilder: (_) => const Icon(Icons.videocam, color: Colors.red),
      fileThumbnailBuilder: fileThumbnailBuilder,
      onFileTap: _playVideo,
      initialGridView: viewMode,
      onGridViewChanged: (v) =>
          ref.read(videoViewModeProvider.notifier).setViewMode(v),
      onCurrentFolderChanged: (f) {
        _currentFolder = f;
        ref.read(filesPageCurrentFolderProvider.notifier).state = f;
      },
      extraPopupMenuItems: (file) => [
        const PopupMenuItem(
          value: 'play',
          child: ListTile(
            leading: Icon(Icons.play_arrow, size: 20),
            title: Text('播放'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: Icon(Icons.file_download, size: 20),
            title: Text('导出到本地'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onExtraMenuAction: (file, value) {
        if (value == 'play') {
          _playVideo(file);
        }
      },
    );

    final navigateToParentSignal = ref.watch(
      filesPageNavigateToParentSignalProvider,
    );
    final tabResetSignal =
        ref.watch(fileTabFolderResetSignalProvider(widget.tabIndex));

    return FileManagerView<VideoRecord>(
      tabResetSignal: tabResetSignal,
      navigateToParentSignal: navigateToParentSignal,
      isActiveTab: widget.isActiveTab,
      sortedRecords: sortedRecords,
      folders: folders,
      sortConfig: sortConfig,
      config: config,
      onRefresh: () async {
        await ref.read(videoRecordsProvider.notifier).loadRecords();
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onRenameFile: (id, newName) async {
        await ref.read(videoRecordsProvider.notifier).renameRecord(id, newName);
      },
      onMoveFile: (id, targetFolder) async {
        await ref
            .read(videoRecordsProvider.notifier)
            .moveRecord(id, targetFolder);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onCopyFile: (id, selectedFolder) async {
        try {
          final source = records.firstWhere((r) => r.id == id);
          String copyName = '${source.name}_副本';
          int copyIdx = 2;
          while (records.any(
            (r) => r.name == copyName && r.folder == selectedFolder,
          )) {
            copyName = '${source.name}_副本 ($copyIdx)';
            copyIdx++;
          }
          await VideoManifest.addRecord(
            VideoRecord(
              name: copyName,
              hash: source.hash,
              format: source.format,
              createdAt: DateTime.now(),
              size: source.size,
              folder: selectedFolder,
            ),
          );
          await ref.read(videoRecordsProvider.notifier).loadRecords();
          await ref.read(videoFolderListProvider.notifier).loadFolders();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('复制失败: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onDeleteFile: (id) async {
        await ref.read(videoRecordsProvider.notifier).deleteRecord(id);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        await ref.read(videoRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
          await ref.read(videoRecordsProvider.notifier).deleteFolder(name);
        }
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onMoveFiles: (ids, targetFolder) async {
        for (final id in ids) {
          await ref
              .read(videoRecordsProvider.notifier)
              .moveRecord(id, targetFolder);
        }
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onMoveFolders: (names, targetFolder) async {
        for (final name in names) {
          await ref
              .read(videoRecordsProvider.notifier)
              .moveFolder(name, targetFolder);
        }
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onExportFile: _exportFile,
      onExportFiles: _exportFiles,
      onExportFolders: _exportFolders,
      onExportFolder: (name) async {
        return _exportFolder(name);
      },
      onRenameFolder: (oldName, newName) async {
        await ref
            .read(videoRecordsProvider.notifier)
            .renameFolder(oldName, newName);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onMoveFolder: (sourceName, targetParent) async {
        await ref
            .read(videoRecordsProvider.notifier)
            .moveFolder(sourceName, targetParent);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onCopyFolder: (sourceName, targetParent) async {
        await ref
            .read(videoRecordsProvider.notifier)
            .copyFolder(sourceName, targetParent);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolder: (name) async {
        await ref.read(videoRecordsProvider.notifier).deleteFolder(name);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onCreateFolder: (name) async {
        await ref.read(videoRecordsProvider.notifier).createFolder(name);
        await ref.read(videoFolderListProvider.notifier).loadFolders();
      },
      onToggleSort: (field) {
        ref.read(videoSortConfigProvider.notifier).toggle(field);
      },
      manifestBridge: ManifestBridge(
        getFolderBaseName: VideoManifest.getFolderBaseName,
        getParentFolderPath: VideoManifest.getParentFolderPath,
        getChildFolderPaths: (parent, allPaths) =>
            VideoManifest.getChildFolderPaths(parent, allPaths.toList()),
        validateFolderName: VideoManifest.validateFolderName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      ),
    );
  }

  /// Generate thumbnail from a video file path using
  /// [CrossPlatformVideoThumbnails].
  Future<Uint8List?> _generateThumbnailFromPath(String videoPath) async {
    try {
      await _ensureThumbnailInitialized();
      final result = await CrossPlatformVideoThumbnails.generateThumbnail(
        videoPath,
        ThumbnailOptions(
          timePosition: 1.0,
          width: 320,
          height: 240,
          quality: 0.8,
          format: ThumbnailFormat.jpeg,
        ),
      );
      if (result.data.isNotEmpty) {
        return Uint8List.fromList(result.data);
      }
    } catch (e) {
      debugPrint('_generateThumbnailFromPath error: $e');
    }
    return null;
  }

  /// Generate thumbnail from video bytes (fallback for when file path is
  /// unavailable, e.g. on some web deployments). Writes bytes to a temp file,
  /// generates thumbnail, then cleans up.
  Future<Uint8List?> _generateThumbnailFromBytes(Uint8List videoBytes) async {
    // On web, we cannot create temp files — rely on path-based generation.
    if (kIsWeb) return null;
    try {
      await _ensureThumbnailInitialized();
      // Write bytes to a temporary file so the package can read it
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/stroom_thumb_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      try {
        await tempFile.writeAsBytes(videoBytes);
        final result = await CrossPlatformVideoThumbnails.generateThumbnail(
          tempFile.path,
          ThumbnailOptions(
            timePosition: 1.0,
            width: 320,
            height: 240,
            quality: 0.8,
            format: ThumbnailFormat.jpeg,
          ),
        );
        if (result.data.isNotEmpty) {
          return Uint8List.fromList(result.data);
        }
      } finally {
        // Clean up temp file
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('_generateThumbnailFromBytes error: $e');
    }
    return null;
  }
}
