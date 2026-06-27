import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../providers/image_provider.dart';
import '../utils/image_manifest.dart';
import '../utils/manifest_bridge.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../widgets/file_manager_view.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/image_preview_dialog.dart';
import 'files_page_shared.dart';
import 'gallery_shared.dart';
import 'image_editor_page.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

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
  }

  /// Formats whose thumbnails / preview are rendered via `Image.memory`.
  static const _supportedFormats = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'wbmp',
  };

  /// Tracks the currently-active folder (synced from FileManagerView).
  String _currentFolder = '';

  /// Guards against re-entrant imports.
  bool _isImporting = false;

  /// 生成缩略图（最大 256x256，保持宽高比）
  Future<Uint8List> generateThumbnail(
    Uint8List imageData, {
    int maxDimension = 256,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return imageData;
      return byteData.buffer.asUint8List();
    } catch (e) {
      // 缩略图生成失败时回退使用原图
      return imageData;
    }
  }

  /// Sanitize a filename: strip path separators, truncate, keep extension.
  String _sanitizeName(String rawName) {
    // Remove path separators and other problematic chars
    var clean = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    // Truncate to 100 chars (excluding extension)
    final extIdx = clean.lastIndexOf('.');
    if (extIdx > 100) {
      clean = '${clean.substring(0, 100)}.${clean.substring(extIdx + 1)}';
    } else if (clean.length > 110) {
      if (extIdx == -1) {
        clean = clean.substring(0, 110);
      } else {
        final ext = clean.substring(extIdx); // includes the dot
        clean = '${clean.substring(0, 110 - ext.length)}$ext';
      }
    }
    return clean;
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  /// Generate a unique file-name for the currently-active folder.
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
  // Image preview (dialog)
  // ====================================================================

  Future<void> _showImagePreview(ImageRecord file) async {
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

    final data = await ImageManifest.readFile(file.storagePath);
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法加载图片')));
      }
      return;
    }

    if (!mounted) return;
    // Show preview dialog; if user taps edit, it returns true
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) => ImagePreviewDialog(
        imageData: data,
        fileName: '${file.name}.${file.format}',
      ),
    );

    // If user wants to edit, open the editor
    if (shouldEdit == true && mounted) {
      final result = await Navigator.push<ImageEditorResult>(
        context,
        MaterialPageRoute(builder: (_) => ImageEditorPage(imageBytes: data)),
      );

      if (result == null || !mounted) return;

      if (result.isSaveAs) {
        // Save as new copy — keep the original, create a new record
        try {
          final editedBytes = result.editedBytes;
          final newHash = computeImageHash(editedBytes);
          final newFileName = '$newHash.${file.format}';
          await ImageManifest.writeFile(newFileName, editedBytes);

          // Generate thumbnail
          final thumbBytes = await generateThumbnail(editedBytes);
          if (thumbBytes.isNotEmpty) {
            await ImageManifest.writeFile('${newHash}_thumb.png', thumbBytes);
          }

          // Create new record
          await ImageManifest.addRecord(
            ImageRecord(
              name: '${file.name}_编辑版',
              hash: newHash,
              format: file.format,
              createdAt: DateTime.now(),
              size: editedBytes.length,
              folder: file.folder,
            ),
          );

          // Refresh
          await ref.read(imageRecordsProvider.notifier).loadRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('图片已另存为新副本'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('另存失败: $e'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        // Overwrite — replace the original file
        try {
          final editedBytes = result.editedBytes;

          // Compute new hash first
          final newHash = computeImageHash(editedBytes);
          final newFileName = '$newHash.${file.format}';

          // Write new file and thumbnail BEFORE deleting the old one
          await ImageManifest.writeFile(newFileName, editedBytes);
          final thumbBytes = await generateThumbnail(editedBytes);
          if (thumbBytes.isNotEmpty) {
            await ImageManifest.writeFile('${newHash}_thumb.png', thumbBytes);
          }

          // Now safe to delete old files
          await ImageManifest.deleteFile(file.storagePath);
          await ImageManifest.deleteFile('${file.hash}_thumb.png');

          // Since copyWith doesn't allow changing hash, update via manifest
          // Delete old record and create new one
          await ImageManifest.deleteRecord(file.id);
          await ImageManifest.addRecord(
            ImageRecord(
              name: file.name,
              hash: newHash,
              format: file.format,
              createdAt: file.createdAt,
              size: editedBytes.length,
              folder: file.folder,
            ),
          );

          // Refresh
          await ref.read(imageRecordsProvider.notifier).loadRecords();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('图片已更新'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存编辑失败: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }
  // ====================================================================
  // Import / export
  // ====================================================================

  Future<void> _takePhoto() async {
    final folders = ref.read(imageFolderListProvider);
    final selectedFolder = await FolderPickerDialog.show(
      context,
      currentFolder: _currentFolder,
      availableFolders: folders,
      title: '拍照添加至文件夹',
      onCreateFolder: (name) async {
        await ref.read(imageRecordsProvider.notifier).createFolder(name);
        return null;
      },
      onRefreshFolders: () async {
        await ref.read(imageFolderListProvider.notifier).loadFolders();
        return ref.read(imageFolderListProvider);
      },
    );
    if (selectedFolder == null || !mounted) return;

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
      final thumbnailBytes = await generateThumbnail(bytes);
      final thumbFileName = '${hash}_thumb.png';
      await ImageManifest.writeFile(thumbFileName, thumbnailBytes);
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
          folder: selectedFolder,
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
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) {
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

      final records = ref.read(imageRecordsProvider);
      final usedInBatch = <String>{};
      var count = 0;
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) continue;
        final hash = computeImageHash(bytes);
        final rawName = _sanitizeName(pickedFile.name);
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
        final thumbnailBytes = await generateThumbnail(bytes);
        final thumbFileName = '${hash}_thumb.png';
        await ImageManifest.writeFile(thumbFileName, thumbnailBytes);
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
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(imageRecordsProvider.notifier).loadRecords();
      await ref.read(imageFolderListProvider.notifier).loadFolders();
      if (mounted) {
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
      // If no directory specified, let user pick a directory
      String? outputDir;
      if (kIsWeb) {
        // Web: no directory picker, save files one by one
        outputDir = ''; // placeholder, not used on web
      } else {
        outputDir = targetDirectory.isNotEmpty ? targetDirectory : null;
        if (outputDir == null) {
          outputDir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
          if (outputDir == null) return;
        }
      }

      if (!mounted) return;

      final records = ref.read(imageRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);
        final data = await ImageManifest.readFile(file.storagePath);
        if (data == null || data.isEmpty) continue;

        final exportName = '${file.name}.${file.format}';
        final outputPath = p.join(outputDir, exportName);

        if (kIsWeb) {
          // On web, we save individually
          await FilePicker.saveFile(
            dialogTitle: '导出图片',
            fileName: exportName,
            type: FileType.custom,
            allowedExtensions: [file.format],
            bytes: data,
          );
        } else {
          // Native: write directly to the selected directory
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
    // For each folder, export all files within preserving folder structure
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

        // Export all files in the folders one by one via save-file dialog
        final records = ref.read(imageRecordsProvider);
        var exportedCount = 0;
        for (final folderName in names) {
          final folderFiles = records
              .where((r) => r.folder == folderName)
              .toList();
          for (final file in folderFiles) {
            final data = await ImageManifest.readFile(file.storagePath);
            if (data == null || data.isEmpty) continue;
            final exportName = '${file.name}.${file.format}';
            await FilePicker.saveFile(
              dialogTitle: '导出图片',
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

      final records = ref.read(imageRecordsProvider);
      var exportedCount = 0;

      for (final folderName in names) {
        final folderFiles = records
            .where((r) => r.folder == folderName)
            .toList();
        if (folderFiles.isEmpty) continue;

        // Create folder in output directory (recreate folder hierarchy)
        final folderOutputDir = p.join(outputDir, folderName);
        await Directory(folderOutputDir).create(recursive: true);

        for (final file in folderFiles) {
          final data = await ImageManifest.readFile(file.storagePath);
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
    // Same behavior as _exportFolders but for a single folder
    await _exportFolders([folderName], '');
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
      int cmp;
      switch (sortConfig.field) {
        case SortField.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
        case SortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortField.size:
          cmp = a.size.compareTo(b.size);
      }
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
                  '从相册导入',
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
        return FutureBuilder<Uint8List?>(
          future: (() async {
            final thumb = await ImageManifest.readFile(
              '${file.hash}_thumb.png',
            );
            if (thumb != null) return thumb;
            return ImageManifest.readFile(file.storagePath);
          })(),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return buildFormatIcon(file.format);
            }
            return Image.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => buildFormatIcon(file.format),
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

    return FileManagerView<ImageRecord>(
      navigateToParentSignal: navigateToParentSignal,
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
      },
      onDeleteFile: (id) async {
        await ref.read(imageRecordsProvider.notifier).deleteRecord(id);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        await ref.read(imageRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(imageFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
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
