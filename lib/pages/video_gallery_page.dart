import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:chewie/chewie.dart';

import '../providers/video_provider.dart';
import '../utils/video_manifest.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../utils/manifest_bridge.dart';
import '../widgets/file_manager_view.dart';
import 'video_capture_page.dart';

class VideoGalleryPage extends ConsumerStatefulWidget {
  const VideoGalleryPage({super.key});

  @override
  ConsumerState<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends ConsumerState<VideoGalleryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoRecordsProvider.notifier).loadRecords();
      ref.read(videoFolderListProvider.notifier).loadFolders();
    });
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => VideoCapturePage(folder: _currentFolder)),
    );

    await ref.read(videoRecordsProvider.notifier).loadRecords();
    await ref.read(videoFolderListProvider.notifier).loadFolders();
    if (mounted) {
      if (result != null && result.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('视频已保存'), duration: Duration(seconds: 2)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('视频列表已刷新'), duration: Duration(seconds: 2)),
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

        await VideoManifest.writeFile(storageFileName, bytes);
        try {
          final videoPath =
              await VideoManifest.readFilePath(storageFileName);
          if (videoPath != null) {
            final thumbBytes = await VideoThumbnail.thumbnailData(
              video: videoPath,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 256,
              quality: 75,
              timeMs: 1000,
            );
            if (thumbBytes != null) {
              await VideoManifest.writeThumbnail(hash, thumbBytes);
            }
          }
        } catch (_) {}
        await VideoManifest.addRecord(VideoRecord(
          name: displayName,
          hash: hash,
          format: format,
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: _currentFolder,
        ));
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
              content: Text('导入失败: $e'), duration: const Duration(seconds: 3)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法加载视频文件')),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件数据读取失败')),
          );
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
              content: Text('导出失败: $e'), duration: const Duration(seconds: 3)),
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
          outputDir = await FilePicker.getDirectoryPath(
            dialogTitle: '选择导出目录',
          );
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
      List<String> names, String targetDirectory) async {
    try {
      if (kIsWeb) {
        if (!mounted) return;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('文件夹导出'),
            content:
                const Text('浏览器暂不支持选择导出目录，你可以逐个导出文件夹内的文件，或使用 App 以获得完整体验。'),
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
        outputDir = await FilePicker.getDirectoryPath(
          dialogTitle: '选择导出目录',
        );
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
                label: const Text('录制视频',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                label: const Text('从相册导入',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(file.duration),
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

    Widget fileThumbnailBuilder(VideoRecord file) {
      return FutureBuilder<Uint8List?>(
        future: VideoManifest.readThumbnail(file.hash),
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
                    errorBuilder: (_, __, ___) =>
                        buildThumbnailFallback(file),
                  ),
                  if (file.duration > 0)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(file.duration),
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
      onCurrentFolderChanged: (f) => _currentFolder = f,
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

    return FileManagerView<VideoRecord>(
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
        while (records
            .any((r) => r.name == copyName && r.folder == selectedFolder)) {
          copyName = '${source.name}_副本 ($copyIdx)';
          copyIdx++;
        }
        await VideoManifest.addRecord(VideoRecord(
          name: copyName,
          hash: source.hash,
          format: source.format,
          createdAt: DateTime.now(),
          size: source.size,
          folder: selectedFolder,
        ));
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

  /// Format duration in milliseconds to mm:ss string.
  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ====================================================================
// Video Player Page
// ====================================================================

class _VideoPlayerPage extends StatefulWidget {
  final String filePath;
  final String displayName;

  const _VideoPlayerPage({
    required this.filePath,
    required this.displayName,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    await controller.initialize();
    final chewie = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      aspectRatio: controller.value.aspectRatio,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
    );
    if (mounted) {
      setState(() {
        _videoPlayerController = controller;
        _chewieController = chewie;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.displayName,
            style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
