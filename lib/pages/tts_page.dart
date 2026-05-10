import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../providers/tts_state_provider.dart';
import '../providers/task_provider.dart';
import '../utils/file_manifest.dart';
import '../utils/manifest_bridge.dart';
import '../utils/folder_path_utils.dart';
import '../utils/sort_config.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_utils.dart';
import '../widgets/file_manager_view.dart';
import 'tts_create_page.dart';
import 'task_list_page.dart';
import 'audio_player_page.dart';

class TtsPage extends ConsumerStatefulWidget {
  const TtsPage({super.key});

  @override
  ConsumerState<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends ConsumerState<TtsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioRecordsProvider.notifier).loadRecords();
      ref.read(folderListProvider.notifier).loadFolders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final runningTasks = ref
          .read(taskListProvider)
          .where((t) => t.status == TaskStatus.running)
          .toList();
      if (runningTasks.isNotEmpty) {
        final errorMsg =
            state == AppLifecycleState.detached ? '应用已退出，合成中断' : '应用进入后台，合成中断';
        ref
            .read(taskListProvider.notifier)
            .failAllRunningTasks(error: errorMsg);
      }
    }
  }

  String _currentFolder = '';
  bool _isImporting = false;

  String _sanitizeName(String rawName) {
    var clean = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final extIdx = clean.lastIndexOf('.');
    if (extIdx > 100) {
      clean = '${clean.substring(0, 100)}.${clean.substring(extIdx + 1)}';
    } else if (clean.length > 110) {
      clean = clean.substring(0, 110);
    }
    return clean;
  }

  String _uniqueAudioName(
      String baseName, List<AudioRecord> records, Set<String> usedInBatch) {
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

  Future<void> _importAudio() async {
    if (_isImporting) return;
    _isImporting = true;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a', 'wma'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

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

      final records = ref.read(audioRecordsProvider);
      final usedInBatch = <String>{};
      var count = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final hash = computeAudioHash(bytes);
        final rawName = _sanitizeName(file.name);
        final ext = p.extension(rawName).replaceAll('.', '').toLowerCase();
        final format = ext.isNotEmpty ? ext : 'wav';
        final displayName = _uniqueAudioName(
          p.basenameWithoutExtension(rawName),
          records,
          usedInBatch,
        );
        usedInBatch.add(displayName);

        await FileManifest.writeFile('$hash.$format', bytes);
        await FileManifest.addRecord(AudioRecord(
          name: displayName,
          hash: hash,
          format: format,
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: _currentFolder,
        ));
        count++;
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await ref.read(audioRecordsProvider.notifier).loadRecords();
      await ref.read(folderListProvider.notifier).loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('已导入 $count 个音频文件'),
              duration: const Duration(seconds: 2)),
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
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _playAudio(AudioRecord file) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AudioPlayerPage(filePath: file.storagePath, displayName: file.name),
      ),
    );
  }

  Future<void> _exportFile(String fileId) async {
    try {
      final records = ref.read(audioRecordsProvider);
      final file = records.firstWhere((r) => r.id == fileId);

      var data = await FileManifest.readFile(file.storagePath);
      if (data == null || data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件数据读取失败')),
          );
        }
        return;
      }

      var exportFormat = file.format;
      final fixed = ensureValidAudioFormat(data,
          requestedFormat: exportFormat, sampleRate: 24000);
      data = fixed.$1;
      exportFormat = fixed.$2;

      final mimeType = getMimeType(exportFormat);
      final exportName = '${file.name}.$exportFormat';

      if (kIsWeb) {
        downloadAudioFile(data, exportName, mimeType);
      } else {
        final outputPath = await FilePicker.saveFile(
          dialogTitle: '导出音频文件',
          fileName: exportName,
          type: FileType.custom,
          allowedExtensions: [exportFormat],
          bytes: data,
        );
        if (outputPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出到: $outputPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _regenerateFile(AudioRecord file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认重新生成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要重新生成音频 "${file.name}" 吗？'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '重新生成后将覆盖原音频文件。',
                    style: TextStyle(
                        color: Colors.orange[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认重新生成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final sourceText = file.sourceText;
    final originalName = file.name;

    if (!mounted) return;
    await ref.read(audioRecordsProvider.notifier).deleteRecord(file.id);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TTSCreatePage(
          initialText: sourceText.isNotEmpty ? sourceText : null,
          isOverwrite: true,
          originalTitle: originalName,
        ),
      ),
    );
  }

  void _shareAudio(String storagePath) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('分享: $storagePath'),
            duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _refreshFileList() async {
    await ref.read(audioRecordsProvider.notifier).loadRecords();
    await ref.read(folderListProvider.notifier).loadFolders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('文件列表已刷新'), duration: Duration(seconds: 2)),
      );
    }
  }

  // ====================================================================
  // Copy-file helper (used by onCopyFile callback)
  // ====================================================================
  Future<void> _copyFile(String id, String selectedFolder) async {
    final records = ref.read(audioRecordsProvider);
    try {
      final source = records.firstWhere((r) => r.id == id);
      String copyName = '${source.name}_副本';
      int copyIdx = 2;
      while (records
          .any((r) => r.name == copyName && r.folder == selectedFolder)) {
        copyName = '${source.name}_副本 ($copyIdx)';
        copyIdx++;
      }
      await FileManifest.addRecord(AudioRecord(
        name: copyName,
        hash: source.hash,
        format: source.format,
        createdAt: DateTime.now(),
        size: source.size,
        folder: selectedFolder,
        sourceText: source.sourceText,
      ));
      await ref.read(audioRecordsProvider.notifier).loadRecords();
      await ref.read(folderListProvider.notifier).loadFolders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('复制失败: $e'), duration: const Duration(seconds: 2)),
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

      final records = ref.read(audioRecordsProvider);
      var exportedCount = 0;

      for (final id in ids) {
        final file = records.firstWhere((r) => r.id == id);

        var data = await FileManifest.readFile(file.storagePath);
        if (data == null || data.isEmpty) continue;

        var exportFormat = file.format;
        final fixed = ensureValidAudioFormat(data,
            requestedFormat: exportFormat, sampleRate: 24000);
        data = fixed.$1;
        exportFormat = fixed.$2;

        final exportName = '${file.name}.$exportFormat';

        if (kIsWeb) {
          final mimeType = getMimeType(exportFormat);
          downloadAudioFile(data, exportName, mimeType);
        } else {
          final outputPath = p.join(outputDir, exportName);
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

        // Export all files in the folders one by one via download
        final records = ref.read(audioRecordsProvider);
        var exportedCount = 0;
        for (final folderName in names) {
          final folderFiles =
              records.where((r) => r.folder == folderName).toList();
          for (final file in folderFiles) {
            var data = await FileManifest.readFile(file.storagePath);
            if (data == null || data.isEmpty) continue;

            var exportFormat = file.format;
            final fixed = ensureValidAudioFormat(data,
                requestedFormat: exportFormat, sampleRate: 24000);
            data = fixed.$1;
            exportFormat = fixed.$2;

            final exportName = '${file.name}.$exportFormat';
            final mimeType = getMimeType(exportFormat);
            downloadAudioFile(data, exportName, mimeType);
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

      final records = ref.read(audioRecordsProvider);
      var exportedCount = 0;

      for (final folderName in names) {
        final folderFiles =
            records.where((r) => r.folder == folderName).toList();
        if (folderFiles.isEmpty) continue;

        // Create folder in output directory (recreate folder hierarchy)
        final folderOutputDir = p.join(outputDir, folderName);
        await Directory(folderOutputDir).create(recursive: true);

        for (final file in folderFiles) {
          var data = await FileManifest.readFile(file.storagePath);
          if (data == null || data.isEmpty) continue;

          var exportFormat = file.format;
          final fixed = ensureValidAudioFormat(data,
              requestedFormat: exportFormat, sampleRate: 24000);
          data = fixed.$1;
          exportFormat = fixed.$2;

          final exportName = '${file.name}.$exportFormat';
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

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(audioRecordsProvider);
    final folders = ref.watch(folderListProvider);
    final sortConfig = ref.watch(audioSortConfigProvider);

    // Sort records
    final sortedRecords = List<AudioRecord>.from(records);
    sortedRecords.sort((a, b) {
      int cmp;
      switch (sortConfig.field) {
        case SortField.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case SortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortField.size:
          cmp = a.size.compareTo(b.size);
          break;
      }
      return sortConfig.order == SortOrder.descending ? -cmp : cmp;
    });

    final runningTasks = ref
        .watch(taskListProvider)
        .where((t) => t.status == TaskStatus.running)
        .length;

    final config = FileManagerConfig<AudioRecord>(
      title: '录音',
      topActionBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TTSCreatePage()));
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('制作录音',
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
                  onPressed: _importAudio,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text('导入音频',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
      onCurrentFolderChanged: (f) => _currentFolder = f,
      showThumbnailToggle: false,
      fileIconBuilder: (file) => Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
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
      onFileTap: (file) => _playAudio(file),
      extraPopupMenuItems: (file) => [
        const PopupMenuItem(
          value: 'play',
          child: ListTile(
              leading: Icon(Icons.play_arrow, size: 20),
              title: Text('播放'),
              dense: true,
              contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'regenerate',
          child: ListTile(
              leading: Icon(Icons.refresh, size: 20),
              title: Text('重新生成'),
              dense: true,
              contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
              leading: Icon(Icons.share, size: 20),
              title: Text('分享'),
              dense: true,
              contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'export',
          child: ListTile(
              leading: Icon(Icons.file_download, size: 20),
              title: Text('导出到本地'),
              dense: true,
              contentPadding: EdgeInsets.zero),
        ),
      ],
      onExtraMenuAction: (file, value) {
        switch (value) {
          case 'play':
            _playAudio(file);
          case 'regenerate':
            _regenerateFile(file);
          case 'share':
            _shareAudio(file.storagePath);
        }
      },
      extraAppBarActions: () => [
        IconButton(
          icon: Badge(
            isLabelVisible: runningTasks > 0,
            label: Text('$runningTasks', style: const TextStyle(fontSize: 10)),
            child: const Icon(Icons.swap_vert),
          ),
          tooltip: '任务列表',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaskListPage()),
            );
          },
        ),
      ],
    );

    return FileManagerView<AudioRecord>(
      sortedRecords: sortedRecords,
      folders: folders,
      sortConfig: sortConfig,
      config: config,
      onRefresh: _refreshFileList,
      onRenameFile: (id, newName) async {
        await ref.read(audioRecordsProvider.notifier).renameRecord(id, newName);
      },
      onMoveFile: (id, targetFolder) async {
        await ref
            .read(audioRecordsProvider.notifier)
            .moveRecord(id, targetFolder);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onCopyFile: _copyFile,
      onDeleteFile: (id) async {
        await ref.read(audioRecordsProvider.notifier).deleteRecord(id);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onDeleteFiles: (ids) async {
        await ref.read(audioRecordsProvider.notifier).deleteRecords(ids);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onDeleteFolders: (names) async {
        for (final name in names) {
          await ref.read(audioRecordsProvider.notifier).deleteFolder(name);
        }
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onMoveFiles: (ids, targetFolder) async {
        for (final id in ids) {
          await ref
              .read(audioRecordsProvider.notifier)
              .moveRecord(id, targetFolder);
        }
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onMoveFolders: (names, targetFolder) async {
        for (final name in names) {
          await ref
              .read(audioRecordsProvider.notifier)
              .moveFolder(name, targetFolder);
        }
        await ref.read(folderListProvider.notifier).loadFolders();
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
            .read(audioRecordsProvider.notifier)
            .renameFolder(oldName, newName);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onMoveFolder: (sourceName, targetParent) async {
        await ref
            .read(audioRecordsProvider.notifier)
            .moveFolder(sourceName, targetParent);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onCopyFolder: (sourceName, targetParent) async {
        await ref
            .read(audioRecordsProvider.notifier)
            .copyFolder(sourceName, targetParent);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onDeleteFolder: (name) async {
        await ref.read(audioRecordsProvider.notifier).deleteFolder(name);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onCreateFolder: (name) async {
        await ref.read(audioRecordsProvider.notifier).createFolder(name);
        await ref.read(folderListProvider.notifier).loadFolders();
      },
      onToggleSort: (field) {
        ref.read(audioSortConfigProvider.notifier).toggle(field);
      },
      manifestBridge: ManifestBridge(
        getFolderBaseName: FileManifest.getFolderBaseName,
        getParentFolderPath: FileManifest.getParentFolderPath,
        getChildFolderPaths: (parent, allPaths) =>
            FileManifest.getChildFolderPaths(parent, allPaths.toList()),
        validateFolderName: FileManifest.validateFolderName,
        getAllDescendantFolderPaths:
            FolderPathUtils.getAllDescendantFolderPaths,
      ),
    );
  }
}
