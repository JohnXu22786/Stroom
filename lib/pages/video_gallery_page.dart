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
import '../widgets/folder_picker_dialog.dart';
import 'files_page_shared.dart';

class VideoGalleryPage extends ConsumerStatefulWidget {
  final int tabIndex;

  const VideoGalleryPage({super.key, this.tabIndex = 0});

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

  /// Sanitize a filename: strip path separators, truncate, keep extension.
  String _sanitizeName(String rawName) {
    var clean = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final extIdx = clean.lastIndexOf('.');
    if (extIdx > 100) {
      clean = '${clean.substring(0, 100)}.${clean.substring(extIdx + 1)}';
    } else if (clean.length > 110) {
      if (extIdx == -1) {
        clean = clean.substring(0, 110);
      } else {
        final ext = clean.substring(extIdx);
        clean = '${clean.substring(0, 110 - ext.length)}$ext';
      }
    }
    return clean;
  }

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
    final folders = ref.read(videoFolderListProvider);
    final folder = await FolderPickerDialog.show(
      context,
      currentFolder: _currentFolder,
      availableFolders: folders,
      title: '录像添加至文件夹',
      onCreateFolder: (name) async {
        // addFolder internally calls loadFolders()
        await ref.read(videoFolderListProvider.notifier).addFolder(name);
        return null;
      },
      onRefreshFolders: () async {
        // Provider state already updated by addFolder() above
        return ref.read(videoFolderListProvider);
      },
    );
    if (folder == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.camera);
      if (pickedFile == null) return;
      if (!mounted) return;

      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isNotEmpty) {
        final hash = computeVideoHash(bytes);
        final rawName = _sanitizeName(pickedFile.name);
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
            folder: folder,
            duration: videoDurationMs,
          ),
        );
      }

      // Close loading indicator
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(videoRecordsProvider.notifier).loadRecords();
      await ref.read(videoFolderListProvider.notifier).loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('视频已保存'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
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
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null) {
        _isImporting = false;
        return;
      }

      if (!mounted) return;
      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isNotEmpty) {
        final hash = computeVideoHash(bytes);
        final rawName = _sanitizeName(pickedFile.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'mp4';
        final storageFileName = '$hash.$format';

        final records = ref.read(videoRecordsProvider);
        final displayName = _uniqueVideoName(
          p.basenameWithoutExtension(rawName),
          records,
          <String>{},
        );

        final videoPath = await VideoManifest.writeFile(storageFileName, bytes);
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
      }

      // Close loading indicator
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(videoRecordsProvider.notifier).loadRecords();
      await ref.read(videoFolderListProvider.notifier).loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已导入视频'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      _isImporting = false;
    } catch (e) {
      _isImporting = false;
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
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

  Future<void> _exportFiles(List<String> ids, String targetDirectory) async {
    try {
      String? outputDir;
      if (kIsWeb) {
        outputDir = '';
      } else {
        outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
        if (outputDir == null) {
          outputDir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
          if (outputDir == null) return;
        }
      }

      if (!mounted) return;

      final records = ref.read(videoRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);
        final data = await VideoManifest.readFile(file.storagePath);
        if (data == null || data.isEmpty) continue;

        final exportName = '${file.name}.${file.format}';
        final outputPath = p.join(outputDir, exportName);

        if (kIsWeb) {
          await FilePicker.saveFile(
            dialogTitle: '导出视频',
            fileName: exportName,
            type: FileType.custom,
            allowedExtensions: [file.format],
            bytes: data,
          );
        } else {
          await File(outputPath).writeAsBytes(data);
        }
        exportedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 $exportedCount 个文件'),
            duration: const Duration(seconds: 2),
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

  Future<void> _exportFolders(
    List<String> names,
    String targetDirectory,
  ) async {
    try {
      if (kIsWeb) {
        if (!mounted) return;
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

        if (action != 'exportFiles' || !mounted) return;

        final records = ref.read(videoRecordsProvider);
        var exportedCount = 0;
        for (final folderName in names) {
          final folderFiles =
              records.where((r) => r.folder == folderName).toList();
          for (final file in folderFiles) {
            final data = await VideoManifest.readFile(file.storagePath);
            if (data == null || data.isEmpty) continue;
            final exportName = '${file.name}.${file.format}';
            await FilePicker.saveFile(
              dialogTitle: '导出视频',
              fileName: exportName,
              type: FileType.custom,
              allowedExtensions: [file.format],
              bytes: data,
            );
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
        return;
      }

      String? outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
      if (outputDir == null) {
        outputDir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
        if (outputDir == null) return;
      }

      if (!mounted) return;

      final records = ref.read(videoRecordsProvider);
      var exportedCount = 0;

      for (final folderName in names) {
        final folderFiles =
            records.where((r) => r.folder == folderName).toList();
        if (folderFiles.isEmpty) continue;

        final folderOutputDir = p.join(outputDir, folderName);
        await Directory(folderOutputDir).create(recursive: true);

        for (final file in folderFiles) {
          final data = await VideoManifest.readFile(file.storagePath);
          if (data == null || data.isEmpty) continue;

          final exportName = '${file.name}.${file.format}';
          final outputPath = p.join(folderOutputDir, exportName);
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

  Future<void> _exportFolder(String folderName) async {
    await _exportFolders([folderName], '');
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
      onExportFiles: (ids, targetDir) async {
        await _exportFiles(ids, targetDir);
      },
      onExportFolders: (names, targetDir) async {
        await _exportFolders(names, targetDir);
      },
      onExportFolder: (name) async {
        await _exportFolder(name);
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
