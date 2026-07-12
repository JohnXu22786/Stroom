import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../providers/text_provider.dart';
import '../utils/text_manifest.dart';
import '../utils/manifest_bridge.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../widgets/file_manager_view.dart';
import 'files_page_shared.dart';
import 'mermaid_chart_page.dart';
import 'text_preview_edit_page.dart';
import 'text_storage_shared.dart';

/// 文本储存区页面 - 管理文本文件，支持导入、创建、预览和导出
class TextStoragePage extends ConsumerStatefulWidget {
  final int tabIndex;
  final bool isActiveTab;

  const TextStoragePage(
      {super.key, this.tabIndex = 0, this.isActiveTab = true});

  @override
  ConsumerState<TextStoragePage> createState() => _TextStoragePageState();
}

class _TextStoragePageState extends ConsumerState<TextStoragePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(textRecordsProvider.notifier).loadRecords();
      ref.read(textFolderListProvider.notifier).loadFolders();
    });
  }

  String _currentFolder = '';
  bool _isImporting = false;

  /// 支持的文本格式
  static const _supportedFormats = {
    'txt',
    'md',
    'mmd',
    'json',
    'xml',
    'csv',
    'yaml',
    'yml',
    'toml',
    'ini',
    'cfg',
    'log',
    'env',
  };

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

  String _uniqueTextName(
    String baseName,
    List<TextRecord> records,
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
  // Import text files
  // ====================================================================

  Future<void> _importTextFile() async {
    if (_isImporting) return;
    _isImporting = true;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedFormats.toList(),
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        _isImporting = false;
        return;
      }

      if (!mounted) return;
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

      final records = ref.read(textRecordsProvider);
      final usedInBatch = <String>{};
      var count = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final content = utf8.decode(bytes);
        final hash = computeTextHash(bytes);
        final rawName = _sanitizeName(file.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'txt';
        if (!_supportedFormats.contains(format)) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('跳过不支持格式: $format')));
          }
          continue;
        }
        final storageFileName = '$hash.txt';

        final displayName = _uniqueTextName(
          p.basenameWithoutExtension(rawName),
          records,
          usedInBatch,
        );
        usedInBatch.add(displayName);

        await TextManifest.writeFile(storageFileName, bytes);
        await TextManifest.addRecord(
          TextRecord(
            name: displayName,
            hash: hash,
            format: format,
            createdAt: DateTime.now(),
            size: bytes.length,
            folder: _currentFolder,
            textLength: content.length,
          ),
        );
        count++;
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(textRecordsProvider.notifier).loadRecords();
      await ref.read(textFolderListProvider.notifier).loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 $count 个文本文件'),
            duration: const Duration(seconds: 2),
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
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isImporting = false;
    }
  }

  // ====================================================================
  // Create new text
  // ====================================================================

  Future<void> _createNewText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextCreatePage(initialFolder: _currentFolder),
      ),
    );

    if (result != null && mounted) {
      await ref.read(textRecordsProvider.notifier).loadRecords();
      await ref.read(textFolderListProvider.notifier).loadFolders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文本已保存'), duration: Duration(seconds: 2)),
      );
    }
  }

  // ====================================================================
  // Preview text content
  // ====================================================================

  Future<void> _previewText(TextRecord file) async {
    final content = await TextManifest.readText(file.storagePath);
    if (!mounted) return;
    if (content == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法加载文本内容')));
      return;
    }

    // .mmd 文件直接打开图表制作页面（三态编辑模式），无需经过普通文本预览
    if (file.format == 'mmd') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MermaidChartPage(initialCode: content),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TextPreviewEditPage(file: file, initialContent: content),
        ),
      );
    }

    if (mounted) {
      await ref.read(textRecordsProvider.notifier).loadRecords();
    }
  }

  // ====================================================================
  // Export
  // ====================================================================

  Future<void> _exportFile(String id) async {
    try {
      final records = ref.read(textRecordsProvider);
      final file = records.firstWhere((r) => r.id == id);

      final content = await TextManifest.readText(file.storagePath);
      if (content == null || content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('文件数据读取失败')));
        }
        return;
      }

      final exportName = '${file.name}.${file.format}';
      final data = Uint8List.fromList(utf8.encode(content));
      final outputPath = await FilePicker.saveFile(
        dialogTitle: '导出文本',
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

      final records = ref.read(textRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);
        final content = await TextManifest.readText(file.storagePath);
        if (content == null || content.isEmpty) continue;

        final exportName = '${file.name}.${file.format}';

        if (kIsWeb) {
          final data = Uint8List.fromList(utf8.encode(content));
          await FilePicker.saveFile(
            dialogTitle: '导出文本',
            fileName: exportName,
            type: FileType.custom,
            allowedExtensions: [file.format],
            bytes: data,
          );
        } else {
          final outputPath = p.join(outputDir, exportName);
          await File(outputPath).writeAsString(content);
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

        final records = ref.read(textRecordsProvider);
        var exportedCount = 0;
        for (final folderName in names) {
          final folderFiles =
              records.where((r) => r.folder == folderName).toList();
          for (final file in folderFiles) {
            final content = await TextManifest.readText(file.storagePath);
            if (content == null || content.isEmpty) continue;
            final exportName = '${file.name}.${file.format}';
            final data = Uint8List.fromList(utf8.encode(content));
            await FilePicker.saveFile(
              dialogTitle: '导出文本',
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

      final records = ref.read(textRecordsProvider);
      var exportedCount = 0;

      for (final folderName in names) {
        final folderFiles =
            records.where((r) => r.folder == folderName).toList();
        if (folderFiles.isEmpty) continue;

        final folderOutputDir = p.join(outputDir, folderName);
        await Directory(folderOutputDir).create(recursive: true);

        for (final file in folderFiles) {
          final content = await TextManifest.readText(file.storagePath);
          if (content == null || content.isEmpty) continue;

          final exportName = '${file.name}.${file.format}';
          final outputPath = p.join(folderOutputDir, exportName);
          await File(outputPath).writeAsString(content);
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
  // Copy file helper
  // ====================================================================

  Future<void> _copyFile(String id, String selectedFolder) async {
    final records = ref.read(textRecordsProvider);
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
      await TextManifest.addRecord(
        TextRecord(
          name: copyName,
          hash: source.hash,
          format: source.format,
          createdAt: DateTime.now(),
          size: source.size,
          folder: selectedFolder,
          textLength: source.textLength,
        ),
      );
      await ref.read(textRecordsProvider.notifier).loadRecords();
      await ref.read(textFolderListProvider.notifier).loadFolders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(textRecordsProvider);
    final folders = ref.watch(textFolderListProvider);
    final sortConfig = ref.watch(textSortConfigProvider);
    final viewMode = ref.watch(textViewModeProvider);

    // Sort records
    final sortedRecords = List<TextRecord>.from(records);
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

    // Top action bar
    final topActionBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _createNewText,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text(
                  '新建',
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
                onPressed: _importTextFile,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 20),
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

    // File icon builder
    Widget fileIconBuilder(TextRecord file) {
      return Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              file.format.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    // FileManagerConfig
    final config = FileManagerConfig<TextRecord>(
      title: '文本',
      topActionBar: topActionBar,
      showThumbnailToggle: false,
      fileIconBuilder: fileIconBuilder,
      onFileTap: _previewText,
      initialGridView: viewMode,
      onGridViewChanged: (v) =>
          ref.read(textViewModeProvider.notifier).setViewMode(v),
      onCurrentFolderChanged: (f) {
        _currentFolder = f;
        ref.read(filesPageCurrentFolderProvider.notifier).state = f;
      },
      extraPopupMenuItems: (file) => [
        const PopupMenuItem(
          value: 'preview',
          child: ListTile(
            leading: Icon(Icons.visibility, size: 20),
            title: Text('预览'),
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
    );

    final navigateToParentSignal =
        ref.watch(filesPageNavigateToParentSignalProvider);
    final tabResetSignal =
        ref.watch(fileTabFolderResetSignalProvider(widget.tabIndex));

    return FileManagerView<TextRecord>(
      tabResetSignal: tabResetSignal,
      navigateToParentSignal: navigateToParentSignal,
      isActiveTab: widget.isActiveTab,
      sortedRecords: sortedRecords,
      folders: folders,
      sortConfig: sortConfig,
      config: config,
      onRefresh: () async {
        await ref.read(textRecordsProvider.notifier).loadRecords();
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onRenameFile: (id, newName) async {
        await ref.read(textRecordsProvider.notifier).renameRecord(id, newName);
      },
      onMoveFile: (id, targetFolder) async {
        await ref
            .read(textRecordsProvider.notifier)
            .moveRecord(id, targetFolder);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onCopyFile: _copyFile,
      onDeleteFile: (id) async {
        await ref.read(textRecordsProvider.notifier).deleteRecord(id);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        await ref.read(textRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
          await ref.read(textRecordsProvider.notifier).deleteFolder(name);
        }
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onMoveFiles: (ids, targetFolder) async {
        for (final id in ids) {
          await ref
              .read(textRecordsProvider.notifier)
              .moveRecord(id, targetFolder);
        }
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onMoveFolders: (names, targetFolder) async {
        for (final name in names) {
          await ref
              .read(textRecordsProvider.notifier)
              .moveFolder(name, targetFolder);
        }
        await ref.read(textFolderListProvider.notifier).loadFolders();
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
            .read(textRecordsProvider.notifier)
            .renameFolder(oldName, newName);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onMoveFolder: (sourceName, targetParent) async {
        await ref
            .read(textRecordsProvider.notifier)
            .moveFolder(sourceName, targetParent);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onCopyFolder: (sourceName, targetParent) async {
        await ref
            .read(textRecordsProvider.notifier)
            .copyFolder(sourceName, targetParent);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onDeleteFolder: (name) async {
        await ref.read(textRecordsProvider.notifier).deleteFolder(name);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onCreateFolder: (name) async {
        await ref.read(textRecordsProvider.notifier).createFolder(name);
        await ref.read(textFolderListProvider.notifier).loadFolders();
      },
      onToggleSort: (field) {
        ref.read(textSortConfigProvider.notifier).toggle(field);
      },
      manifestBridge: ManifestBridge(
        getFolderBaseName: TextManifest.getFolderBaseName,
        getParentFolderPath: TextManifest.getParentFolderPath,
        getChildFolderPaths: (parent, allPaths) =>
            TextManifest.getChildFolderPaths(parent, allPaths.toList()),
        validateFolderName: TextManifest.validateFolderName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      ),
    );
  }
}
