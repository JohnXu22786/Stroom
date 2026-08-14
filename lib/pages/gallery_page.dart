import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:extended_image/extended_image.dart';

import '../providers/image_provider.dart';
import '../utils/image_manifest.dart';
import '../utils/image_thumbnail_loader.dart';
import '../utils/manifest_bridge.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../utils/system_pick_utils.dart';
import '../widgets/file_manager_view.dart';
import '../widgets/file_manager_utils.dart';
import 'files_page_shared.dart';
import 'gallery_shared.dart';
import 'gallery_viewer_page.dart';

class GalleryPage extends ConsumerStatefulWidget {
  final int tabIndex;
  final bool isActiveTab;

  const GalleryPage({super.key, this.tabIndex = 0, this.isActiveTab = true});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageRecordsProvider.notifier).loadRecords();
      ref.read(imageFolderListProvider.notifier).loadFolders();
    });
    // 重新进入文件页（切换底部导航）时 filesRefreshSignalProvider 递增：
    // 只重载数据，不重建页面，保留已打开的文件夹层级。
    ref.listenManual(filesRefreshSignalProvider, (prev, next) {
      ref.read(imageRecordsProvider.notifier).loadRecords();
      ref.read(imageFolderListProvider.notifier).loadFolders();
    });
  }

  /// Formats whose thumbnails / preview are rendered via `ExtendedImage`.
  static const _supportedFormats = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'wbmp',
    'svg',
  };

  /// Tracks the currently-active folder (synced from FileManagerView).
  String _currentFolder = '';

  /// Guards against re-entrant imports.
  bool _isImporting = false;

  /// Guards against re-entrant image preview (double-tap while loading).
  bool _isPreviewing = false;

  /// 缩略图解码目标尺寸（与生成尺寸一致：≤256px，宽高比保持）
  static const int _thumbDecodeSize = 256;

  /// Sanitize a filename: strip path separators, truncate, keep extension.
  String _uniqueImageName(
    String baseName,
    List<ImageRecord> records,
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
  // Image preview (full-screen gallery viewer)
  // ====================================================================

  /// 记录被删除后丢弃其缩略图内存缓存（hash 键控，防陈旧字节驻留）。
  void _invalidateThumbnails(Iterable<ImageRecord> recs) {
    for (final r in recs) {
      ImageThumbnailLoader.invalidate(r.hash);
    }
  }

  Future<void> _showImagePreview(ImageRecord file) async {
    if (_isPreviewing) return;
    _isPreviewing = true;
    try {
      if (!_supportedFormats.contains(file.format)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('不支持预览 .${file.format} 格式'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Get all images in the current folder for gallery browsing
      final records = ref.read(imageRecordsProvider);
      final folderImages = records
          .where((r) =>
              r.folder == file.folder && _supportedFormats.contains(r.format))
          .toList();
      final initialIndex = folderImages.indexWhere((r) => r.id == file.id);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryViewerPage(
            images: folderImages,
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ),
        ),
      );

      // Refresh records after returning from viewer — edits (overwrite / save-as)
      // create new records with new hashes, and the gallery grid needs to reflect
      // these changes immediately.
      ref.read(imageRecordsProvider.notifier).loadRecords();
    } finally {
      _isPreviewing = false;
    }
  }
  // ====================================================================
  // Import / export
  // ====================================================================

  Future<void> _takePhoto() async {
    // 直接保存到当前正在浏览的文件夹（_currentFolder），不再弹文件夹选择
    var success = false;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      if (!mounted) return;

      final bytes = await file.readAsBytes();
      final hash = computeImageHash(bytes);
      const format = 'jpg';
      final fileName = '$hash.$format';
      await ImageManifest.writeFile(fileName, bytes);
      final thumbnailBytes =
          await ImageThumbnailLoader.generateThumbnail(bytes);
      if (thumbnailBytes != null) {
        await ImageManifest.writeFile('${hash}_thumb.png', thumbnailBytes);
      }
      final now = DateTime.now();
      final timestamp =
          '${now.year}${padInt(now.month)}${padInt(now.day)}_${padInt(now.hour)}${padInt(now.minute)}${padInt(now.second)}';
      await ImageManifest.addRecord(
        ImageRecord(
          name: '照片_$timestamp',
          hash: hash,
          format: format,
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: _currentFolder,
        ),
      );
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    await ref.read(imageRecordsProvider.notifier).loadRecords();
    await ref.read(imageFolderListProvider.notifier).loadFolders();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片已保存'), duration: Duration(seconds: 2)),
      );
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
      // 移动端直接打开系统相册（图片专用选择 UI），
      // 桌面端打开文件选择器并定位到系统"图片"目录
      final pickedFiles = await pickSystemMedia(SystemMediaKind.image);
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

      final records = ref.read(imageRecordsProvider);
      final usedInBatch = <String>{};
      var count = 0;
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) continue;
        final hash = computeImageHash(bytes);
        final rawName = sanitizeFileName(pickedFile.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'jpg';
        if (!_supportedFormats.contains(format)) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('跳过不支持格式: $format')));
          }
          continue;
        }
        final storageFileName = '$hash.$format';
        final displayName = _uniqueImageName(
          p.basenameWithoutExtension(rawName),
          records,
          usedInBatch,
        );
        usedInBatch.add(displayName);

        await ImageManifest.writeFile(storageFileName, bytes);
        final thumbnailBytes = await ImageThumbnailLoader.generateThumbnail(
          bytes,
        );
        if (thumbnailBytes != null) {
          await ImageManifest.writeFile('${hash}_thumb.png', thumbnailBytes);
        }
        await ImageManifest.addRecord(
          ImageRecord(
            name: displayName,
            hash: hash,
            format: format,
            createdAt: DateTime.now(),
            size: bytes.length,
            folder: _currentFolder,
          ),
        );
        count++;
      }

      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      await ref.read(imageRecordsProvider.notifier).loadRecords();
      await ref.read(imageFolderListProvider.notifier).loadFolders();
      // 没有任何文件被导入（如全部跳过）时不显示成功提示
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 $count 张图片'),
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

  Future<void> _exportFile(String id) async {
    try {
      final records = ref.read(imageRecordsProvider);
      final file = records.firstWhere((r) => r.id == id);

      final data = await ImageManifest.readFile(file.storagePath);
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
        dialogTitle: '导出图片',
        fileName: exportName,
        type: FileType.custom,
        allowedExtensions: [file.format],
        bytes: data,
        initialDirectory: SystemPickDirectories.pictures(),
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
      // If no directory specified, let user pick a directory
      String? outputDir;
      if (kIsWeb) {
        // Web: no directory picker, save files one by one
        outputDir = ''; // placeholder, not used on web
      } else {
        outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
        if (outputDir == null) {
          outputDir = await FilePicker.getDirectoryPath(
            dialogTitle: '选择导出目录',
            initialDirectory: SystemPickDirectories.pictures(),
          );
          if (outputDir == null) return null;
        }
      }

      if (!mounted) return null;

      final records = ref.read(imageRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);
        final data = await ImageManifest.readFile(file.storagePath);
        if (data == null || data.isEmpty) continue;

        final exportName = '${file.name}.${file.format}';

        if (kIsWeb) {
          // On web, we save individually; cancelled saves don't count
          final saved = await FilePicker.saveFile(
            dialogTitle: '导出图片',
            fileName: exportName,
            type: FileType.custom,
            allowedExtensions: [file.format],
            bytes: data,
            initialDirectory: SystemPickDirectories.pictures(),
          );
          // 用户取消保存时不计数
          if (saved == null) continue;
        } else {
          // Native: write directly to the selected directory
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
    // For each folder, export all files within preserving folder structure
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

        // Export all files in the folders one by one via save-file dialog
        final records = ref.read(imageRecordsProvider);
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
            final data = await ImageManifest.readFile(file.storagePath);
            if (data == null || data.isEmpty) continue;
            final exportName = '${file.name}.${file.format}';
            // 用户取消保存时不计数
            final saved = await FilePicker.saveFile(
              dialogTitle: '导出图片',
              fileName: exportName,
              type: FileType.custom,
              allowedExtensions: [file.format],
              bytes: data,
              initialDirectory: SystemPickDirectories.pictures(),
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
        outputDir = await FilePicker.getDirectoryPath(
          dialogTitle: '选择导出目录',
          initialDirectory: SystemPickDirectories.pictures(),
        );
        if (outputDir == null) return null;
      }

      if (!mounted) return null;

      final records = ref.read(imageRecordsProvider);
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
          final data = await ImageManifest.readFile(file.storagePath);
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
    // Same behavior as _exportFolders but for a single folder
    return _exportFolders([folderName], '');
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(imageRecordsProvider);
    final folders = ref.watch(imageFolderListProvider);
    final sortConfig = ref.watch(imageSortConfigProvider);
    final viewMode = ref.watch(imageViewModeProvider);

    // Sort records
    final sortedRecords = List<ImageRecord>.from(records);
    sortedRecords.sort((a, b) {
      final cmp = compareFileRecords(a, b, sortConfig.field);
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
                onPressed: _takePhoto,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text(
                  '拍照',
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

    // Build file-thumbnail builder
    Widget fileThumbnailBuilder(ImageRecord file) {
      final canPreview = _supportedFormats.contains(file.format);
      if (canPreview) {
        final isSvg = file.format.toLowerCase() == 'svg';
        if (isSvg) {
          return FutureBuilder<Uint8List?>(
            future: ImageManifest.readFile(file.storagePath),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.isEmpty) {
                return buildFormatIcon(file.format);
              }
              return SvgPicture.memory(
                data,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholderBuilder: (_) => const SizedBox(),
              );
            },
          );
        }
        return FutureBuilder<Uint8List?>(
          // 统一走 ImageThumbnailLoader：内存 LRU 缓存避免网格反复读盘，
          // 缩略图缺失时按需生成并持久化，不再回退整张原图
          future: ImageThumbnailLoader.loadThumbnail(file),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return buildFormatIcon(file.format);
            }
            return ExtendedImage.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              // 缩略图按 ≤256px 解码，即使生成失败回退到原图路径
              // 也不会以全分辨率解码多 MB 图片
              cacheWidth: _thumbDecodeSize,
              cacheHeight: _thumbDecodeSize,
              loadStateChanged: (state) {
                if (state.extendedImageLoadState == LoadState.failed) {
                  return buildFormatIcon(file.format);
                }
                return null;
              },
            );
          },
        );
      }
      return buildFormatIcon(file.format);
    }

    // FileManagerConfig
    final config = FileManagerConfig<ImageRecord>(
      title: '相册',
      topActionBar: topActionBar,
      showThumbnailToggle: true,
      fileIconBuilder: (_) => const Icon(Icons.image, color: Colors.blueGrey),
      fileThumbnailBuilder: fileThumbnailBuilder,
      onFileTap: _showImagePreview,
      initialGridView: viewMode,
      onGridViewChanged: (v) =>
          ref.read(imageViewModeProvider.notifier).setViewMode(v),
      onCurrentFolderChanged: (f) {
        _currentFolder = f;
        ref.read(filesPageCurrentFolderProvider.notifier).state = f;
      },
      extraPopupMenuItems: (file) => [
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
    );

    final navigateToParentSignal = ref.watch(
      filesPageNavigateToParentSignalProvider,
    );
    final tabResetSignal =
        ref.watch(fileTabFolderResetSignalProvider(widget.tabIndex));

    return FileManagerView<ImageRecord>(
      tabResetSignal: tabResetSignal,
      navigateToParentSignal: navigateToParentSignal,
      isActiveTab: widget.isActiveTab,
      sortedRecords: sortedRecords,
      folders: folders,
      sortConfig: sortConfig,
      config: config,
      onRefresh: () async {
        await ref.read(imageRecordsProvider.notifier).loadRecords();
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onRenameFile: (id, newName) async {
        await ref.read(imageRecordsProvider.notifier).renameRecord(id, newName);
      },
      onMoveFile: (id, targetFolder) async {
        await ref
            .read(imageRecordsProvider.notifier)
            .moveRecord(id, targetFolder);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
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
          await ImageManifest.addRecord(
            ImageRecord(
              name: copyName,
              hash: source.hash,
              format: source.format,
              createdAt: DateTime.now(),
              size: source.size,
              folder: selectedFolder,
            ),
          );
          await ref.read(imageRecordsProvider.notifier).loadRecords();
          await ref.read(imageFolderListProvider.notifier).loadFolders();
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
        _invalidateThumbnails(records.where((r) => r.id == id));
        await ref.read(imageRecordsProvider.notifier).deleteRecord(id);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        final idSet = ids.toSet();
        _invalidateThumbnails(records.where((r) => idSet.contains(r.id)));
        await ref.read(imageRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
          _invalidateThumbnails(
            records.where(
              (r) => r.folder == name || r.folder.startsWith('$name/'),
            ),
          );
          await ref.read(imageRecordsProvider.notifier).deleteFolder(name);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFiles: (ids, targetFolder) async {
        for (final id in ids) {
          await ref
              .read(imageRecordsProvider.notifier)
              .moveRecord(id, targetFolder);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFolders: (names, targetFolder) async {
        for (final name in names) {
          await ref
              .read(imageRecordsProvider.notifier)
              .moveFolder(name, targetFolder);
        }
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onExportFile: _exportFile,
      onExportFiles: _exportFiles,
      onExportFolders: _exportFolders,
      onExportFolder: (name) async {
        return _exportFolder(name);
      },
      onRenameFolder: (oldName, newName) async {
        await ref
            .read(imageRecordsProvider.notifier)
            .renameFolder(oldName, newName);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onMoveFolder: (sourceName, targetParent) async {
        await ref
            .read(imageRecordsProvider.notifier)
            .moveFolder(sourceName, targetParent);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onCopyFolder: (sourceName, targetParent) async {
        await ref
            .read(imageRecordsProvider.notifier)
            .copyFolder(sourceName, targetParent);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolder: (name) async {
        _invalidateThumbnails(
          records.where(
            (r) => r.folder == name || r.folder.startsWith('$name/'),
          ),
        );
        await ref.read(imageRecordsProvider.notifier).deleteFolder(name);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onCreateFolder: (name) async {
        await ref.read(imageRecordsProvider.notifier).createFolder(name);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onToggleSort: (field) {
        ref.read(imageSortConfigProvider.notifier).toggle(field);
      },
      manifestBridge: ManifestBridge(
        getFolderBaseName: ImageManifest.getFolderBaseName,
        getParentFolderPath: ImageManifest.getParentFolderPath,
        getChildFolderPaths: (parent, allPaths) =>
            ImageManifest.getChildFolderPaths(parent, allPaths.toList()),
        validateFolderName: ImageManifest.validateFolderName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      ),
    );
  }
}
