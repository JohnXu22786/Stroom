import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../providers/tts_state_provider.dart';
import '../providers/task_provider.dart';
import '../utils/file_manifest.dart';
import '../utils/audio_playback.dart';
import '../utils/audio_utils.dart';
import 'tts_create_page.dart';
import 'task_list_page.dart';
import 'audio_player_page.dart';

class TtsPage extends ConsumerStatefulWidget {
  const TtsPage({super.key});

  @override
  ConsumerState<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends ConsumerState<TtsPage> with WidgetsBindingObserver {
  final _folderNameController = TextEditingController();
  final _renameController = TextEditingController();
  String? _selectedFileId;

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // 当前浏览的文件夹，'' 表示根目录
  String _currentFolder = '';

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
    _folderNameController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台/被挂起/即将退出时，标记运行中的任务为失败
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final runningTasks = ref.read(taskListProvider)
          .where((t) => t.status == TaskStatus.running)
          .toList();
      if (runningTasks.isNotEmpty) {
        final errorMsg = state == AppLifecycleState.detached
            ? '应用已退出，合成中断'
            : '应用进入后台，合成中断';
        ref.read(taskListProvider.notifier)
            .failAllRunningTasks(error: errorMsg);
      }
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  Future<void> _createFolder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final name = _folderNameController.text.trim();
              if (name.isNotEmpty && FileManifest.validateFolderName(name) == null) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final error = FileManifest.validateFolderName(result);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
          );
        }
        return;
      }
      _folderNameController.clear();
      await ref.read(audioRecordsProvider.notifier).createFolder(result);
      await ref.read(folderListProvider.notifier).loadFolders();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件夹 "$result" 创建成功'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _renameFile(String fileId, String currentName) async {
    _renameController.text = currentName;
    _selectedFileId = fileId;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名文件'),
        content: TextField(
          controller: _renameController,
          decoration: const InputDecoration(hintText: '输入新名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (_renameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, _renameController.text.trim());
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && _selectedFileId != null) {
      if (!mounted) return;
      await ref.read(audioRecordsProvider.notifier).renameRecord(_selectedFileId!, result);
      _renameController.clear();
      _selectedFileId = null;
    }
  }

  Future<void> _moveFile(String fileId) async {
    final folders = await ref.read(audioRecordsProvider.notifier).getFolders();

    final selectedFolder = await _showFolderPickerDialog(folders, title: '选择目标文件夹');

    if (selectedFolder != null) {
      if (!mounted) return;
      await ref.read(audioRecordsProvider.notifier).moveRecord(fileId, selectedFolder);
      await ref.read(folderListProvider.notifier).loadFolders();
    }
  }

  Future<void> _copyFile(String fileId) async {
    final records = ref.read(audioRecordsProvider);
    final folders = await ref.read(audioRecordsProvider.notifier).getFolders();

    final selectedFolder = await _showFolderPickerDialog(folders, title: '选择复制到的目标文件夹');
    if (selectedFolder == null) return;

    try {
      final source = records.firstWhere((r) => r.id == fileId);
      await FileManifest.addRecord(AudioRecord(
        name: '${source.name}_副本',
        hash: source.hash,
        format: source.format,
        createdAt: DateTime.now(),
        size: source.size,
        folder: selectedFolder,
        sourceText: source.sourceText,
      ));
      await ref.read(audioRecordsProvider.notifier).loadRecords();
      await ref.read(folderListProvider.notifier).loadFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件复制成功'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _deleteFile(String fileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此文件吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await ref.read(audioRecordsProvider.notifier).deleteRecord(fileId);
      await ref.read(folderListProvider.notifier).loadFolders();
      _exitSelectionMode();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个文件吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await ref.read(audioRecordsProvider.notifier).deleteRecords(_selectedIds.toList());
      await ref.read(folderListProvider.notifier).loadFolders();
      _exitSelectionMode();
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty) return;

    final folders = await ref.read(audioRecordsProvider.notifier).getFolders();

    final selectedFolder = await _showFolderPickerDialog(folders, title: '选择目标文件夹');

    if (selectedFolder != null) {
      if (!mounted) return;
      final notifier = ref.read(audioRecordsProvider.notifier);
      for (final id in _selectedIds) {
        await notifier.moveRecord(id, selectedFolder);
      }
      await ref.read(folderListProvider.notifier).loadFolders();
      _exitSelectionMode();
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
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '重新生成后将覆盖原音频文件。',
                    style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认重新生成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 保存原始文本和标题，用于传递
    final sourceText = file.sourceText;
    final originalName = file.name;

    // 删除原记录（实现覆盖效果）
    if (!mounted) return;
    await ref.read(audioRecordsProvider.notifier).deleteRecord(file.id);

    if (!mounted) return;
    // 导航到生成页面，自动填入原始文本和标题
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

  Future<void> _playAudio(String filePath, String? displayName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(filePath: filePath, displayName: displayName),
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
      final fixed = ensureValidAudioFormat(data, requestedFormat: exportFormat, sampleRate: 24000);
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

  Future<void> _shareAudio(String storagePath) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享: $storagePath'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _refreshFileList() async {
    await ref.read(audioRecordsProvider.notifier).loadRecords();
    await ref.read(folderListProvider.notifier).loadFolders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件列表已刷新'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _renameFolder(String folderName) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: folderName);
        return AlertDialog(
          title: const Text('重命名文件夹'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '输入新名称', border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && FileManifest.validateFolderName(name) == null) {
                  Navigator.pop(ctx, name);
                }
              },
              child: const Text('重命名'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != folderName) {
      final error = FileManifest.validateFolderName(result);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
          );
        }
        return;
      }
      if (!mounted) return;
      await ref.read(audioRecordsProvider.notifier).renameFolder(folderName, result);
      if (_currentFolder == folderName || _currentFolder.startsWith('$folderName/')) {
        final parentPath = FileManifest.getParentFolderPath(folderName);
        final newFullPath = parentPath.isEmpty ? result : '$parentPath/$result';
        if (_currentFolder == folderName) {
          setState(() => _currentFolder = newFullPath);
        } else if (_currentFolder.startsWith('$folderName/')) {
          final suffix = _currentFolder.substring(folderName.length);
          setState(() => _currentFolder = '$newFullPath$suffix');
        }
      }
      await ref.read(folderListProvider.notifier).loadFolders();
    }
  }

  Future<void> _moveFolder(String folderName) async {
    final folders = await ref.read(audioRecordsProvider.notifier).getFolders();
    // 排除自己及其所有子文件夹（不能移入自身或后代）
    final descendants = FileManifest.getAllDescendantFolderPaths(folderName);
    final excluded = {folderName, ...descendants};
    final targetFolders = folders.where((f) => !excluded.contains(f)).toSet();

    final selectedFolder = await _showFolderPickerDialog(targetFolders, title: '移动文件夹到…');
    if (selectedFolder == null) return;

    if (!mounted) return;
    await ref.read(audioRecordsProvider.notifier).moveFolder(folderName, selectedFolder);
    if (_currentFolder == folderName) {
      setState(() => _currentFolder = FileManifest.getParentFolderPath(folderName));
    }
    await ref.read(folderListProvider.notifier).loadFolders();
  }

  Future<void> _copyFolder(String folderName) async {
    final folders = await ref.read(audioRecordsProvider.notifier).getFolders();
    // 排除自己及其所有子文件夹（不能复制到自身或后代）
    final descendants = FileManifest.getAllDescendantFolderPaths(folderName);
    final excluded = {folderName, ...descendants};
    final targetFolders = folders.where((f) => !excluded.contains(f)).toSet();

    final selectedFolder = await _showFolderPickerDialog(targetFolders, title: '复制文件夹到…');
    if (selectedFolder == null) return;

    if (!mounted) return;
    await ref.read(audioRecordsProvider.notifier).copyFolder(folderName, selectedFolder);
    await ref.read(folderListProvider.notifier).loadFolders();
  }

  Future<void> _deleteFolder(String folderName) async {
    final records = ref.read(audioRecordsProvider);
    final directCount = records.where((r) => r.folder == folderName).length;
    final descendants = FileManifest.getAllDescendantFolderPaths(folderName);
    int subFileCount = 0;
    for (final desc in descendants) {
      subFileCount += records.where((r) => r.folder == desc).length;
    }
    final fileCount = directCount + subFileCount;
    final message = fileCount > 0
        ? '确定要删除文件夹 "$folderName" 吗？其中的 $fileCount 个文件也将被删除。'
        : '确定要删除空文件夹 "$folderName" 吗？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除文件夹'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final notifier = ref.read(audioRecordsProvider.notifier);
      await notifier.deleteFolder(folderName);
      if (_currentFolder == folderName) {
        setState(() => _currentFolder = FileManifest.getParentFolderPath(folderName));
      }
      await ref.read(folderListProvider.notifier).loadFolders();
    }
  }

  /// 统一的文件夹选择对话框 — 树状层级导航，左下角可新建文件夹（内联编辑）
  Future<String?> _showFolderPickerDialog(Set<String> folders, {String title = '选择目标文件夹'}) async {
    final nameController = TextEditingController();
    final focusNode = FocusNode();
    var isCreating = false;
    var pickerCurrentPath = '';
    var currentFolders = Set<String>.from(folders);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 当前路径下的直接子文件夹
          final subFolders = FileManifest.getChildFolderPaths(pickerCurrentPath, currentFolders.toList());

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 当前路径指示条 + 返回按钮
                  _buildPickerPathBar(pickerCurrentPath, () {
                    setDialogState(() {
                      pickerCurrentPath = FileManifest.getParentFolderPath(pickerCurrentPath);
                    });
                  }),
                  const Divider(height: 1),
                  // 文件夹列表
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // 根目录标识
                        if (pickerCurrentPath.isEmpty)
                          const ListTile(
                            leading: Icon(Icons.home_outlined),
                            title: Text('（根目录）'),
                            dense: true,
                            selected: true,
                          ),
                        if (subFolders.isEmpty && !isCreating)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('此文件夹为空', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ...subFolders.map((f) => ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(FileManifest.getFolderBaseName(f)),
                          dense: true,
                          onTap: () {
                            setDialogState(() {
                              pickerCurrentPath = f;
                            });
                          },
                        )),
                        // 内联新建文件夹编辑行
                        if (isCreating) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: nameController,
                                    focusNode: focusNode,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: '输入文件夹名称',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onSubmitted: (value) async {
                                      final name = value.trim();
                                      if (name.isEmpty) return;
                                      final error = FileManifest.validateFolderName(name);
                                      if (error != null) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
                                          );
                                        }
                                        return;
                                      }
                                      final newPath = pickerCurrentPath.isEmpty ? name : '$pickerCurrentPath/$name';
                                      await ref.read(audioRecordsProvider.notifier).createFolder(newPath);
                                      await ref.read(folderListProvider.notifier).loadFolders();
                                      final updatedFolders = await ref.read(audioRecordsProvider.notifier).getFolders();
                                      setDialogState(() {
                                        currentFolders = Set<String>.from(updatedFolders);
                                        isCreating = false;
                                        nameController.clear();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  tooltip: '确认创建',
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) return;
                                    final error = FileManifest.validateFolderName(name);
                                    if (error != null) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
                                        );
                                      }
                                      return;
                                    }
                                    final newPath = pickerCurrentPath.isEmpty ? name : '$pickerCurrentPath/$name';
                                    await ref.read(audioRecordsProvider.notifier).createFolder(newPath);
                                    await ref.read(folderListProvider.notifier).loadFolders();
                                    final updatedFolders = await ref.read(audioRecordsProvider.notifier).getFolders();
                                    setDialogState(() {
                                      currentFolders = Set<String>.from(updatedFolders);
                                      isCreating = false;
                                      nameController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isCreating)
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() => isCreating = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
                      },
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('新建文件夹'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, pickerCurrentPath),
                        child: const Text('选择此文件夹'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    focusNode.dispose();
    return result;
  }

  /// 文件夹选择器中的路径指示条
  Widget _buildPickerPathBar(String currentPath, VoidCallback onBack) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: '返回上级',
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Text(
              currentPath.isEmpty ? '根目录' : currentPath,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(audioRecordsProvider);

    // Group records by folder
    final grouped = <String, List<AudioRecord>>{};
    for (final r in records) {
      final folder = r.folder.isEmpty ? '' : r.folder;
      grouped.putIfAbsent(folder, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '已选择 ${_selectedIds.length} 项'
              : _currentFolder.isNotEmpty
                  ? _currentFolder
                  : '录音',
        ),
        centerTitle: true,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : (_currentFolder.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _currentFolder = FileManifest.getParentFolderPath(_currentFolder)),
                  )
                : null),
        actions: [
          if (!_selectionMode) ...[
            IconButton(
              icon: Badge(
                isLabelVisible: ref.watch(taskListProvider).where((t) => t.status == TaskStatus.running).isNotEmpty,
                label: Text(
                  '${ref.watch(taskListProvider).where((t) => t.status == TaskStatus.running).length}',
                  style: const TextStyle(fontSize: 10),
                ),
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
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: '创建文件夹',
              onPressed: _createFolder,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新列表',
              onPressed: _refreshFileList,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 制作录音按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TTSCreatePage()));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 22),
                        SizedBox(width: 10),
                        Text('制作录音', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
            ),
          ),

          // 文件列表 — 类文件管理器视图
          Expanded(
            child: _buildFileListView(records, grouped),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        label: const Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _moveSelected,
                        icon: const Icon(Icons.drive_file_move_outline, size: 20),
                        label: const Text('移动'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFileItem(AudioRecord file) {
    final isSelected = _selectedIds.contains(file.id);
    final fileSizeStr = _formatFileSize(file.size);
    final dateStr = _formatDate(file.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(file.id);
          } else {
            _playAudio(file.storagePath, file.name);
          }
        },
        onLongPress: () {
          if (!_selectionMode) {
            _enterSelectionMode(file.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              if (_selectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(file.id),
                ),
              // File icon
              Container(
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (file.folder.isNotEmpty) ...[
                          Icon(Icons.folder, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(file.folder, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          const SizedBox(width: 6),
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey[400]!, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 6),
                        Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey[400]!, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(fileSizeStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              // Popup menu
              if (!_selectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'play': _playAudio(file.storagePath, file.name);
                      case 'regenerate': _regenerateFile(file);
                      case 'rename': _renameFile(file.id, file.name);
                      case 'move': _moveFile(file.id);
                      case 'copy': _copyFile(file.id);
                      case 'share': _shareAudio(file.storagePath);
                      case 'export': _exportFile(file.id);
                      case 'delete': _deleteFile(file.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow, size: 20), title: Text('播放'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'regenerate', child: ListTile(leading: Icon(Icons.refresh, size: 20), title: Text('重新生成'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('重命名'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'move', child: ListTile(leading: Icon(Icons.drive_file_move, size: 20), title: Text('移动'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy, size: 20), title: Text('复制'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share, size: 20), title: Text('分享'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download, size: 20), title: Text('导出到本地'), dense: true, contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 20, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 类文件管理器视图：文件夹可点击进入，不展开文件
  Widget _buildFileListView(
    List<AudioRecord> records,
    Map<String, List<AudioRecord>> grouped,
  ) {
    final isInFolder = _currentFolder.isNotEmpty;

    // 当前目录下的子文件夹（使用路径工具获取直接子级）
    final subFolders = FileManifest.getChildFolderPaths(_currentFolder);

    // 当前目录下的文件（folder字段完全匹配当前路径）
    final currentFiles = isInFolder
        ? (grouped[_currentFolder] ?? [])
        : (grouped[''] ?? []);

    final hasContent = subFolders.isNotEmpty || currentFiles.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInFolder ? Icons.folder_open_outlined : Icons.audio_file_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isInFolder ? '此文件夹为空' : '暂无录音文件',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (!isInFolder)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('点击上方按钮创建您的第一个录音', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // 文件夹内时显示返回按钮
        if (isInFolder)
          _buildBackItem(),

        // 当前目录下的文件夹
        for (final folderName in subFolders)
          _buildFolderItem(folderName, grouped[folderName]?.length ?? 0),

        // 当前目录下的文件
        ...currentFiles.map((r) => _buildFileItem(r)),
      ],
    );
  }

  /// 返回上一级
  Widget _buildBackItem() {
    final parentFolder = FileManifest.getParentFolderPath(_currentFolder);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _currentFolder = parentFolder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Text(parentFolder.isEmpty ? '返回根目录' : '返回: ${FileManifest.getFolderBaseName(parentFolder)}',
                  style: TextStyle(fontSize: 15, color: Colors.blue[700])),
              const Spacer(),
              Text(FileManifest.getFolderBaseName(_currentFolder),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  /// 文件夹详情文本：显示文件数和子文件夹数
  String _folderDetailText(String folderName, int fileCount) {
    final subFolderCount = FileManifest.getChildFolderPaths(folderName).length;
    if (subFolderCount > 0 && fileCount > 0) {
      return '$fileCount 个文件, $subFolderCount 个子文件夹';
    } else if (subFolderCount > 0) {
      return '$subFolderCount 个子文件夹';
    } else {
      return '$fileCount 个文件';
    }
  }

  /// 文件夹卡片 — 与文件卡片保持完全一致的尺寸和样式
  Widget _buildFolderItem(String folderName, int fileCount) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _currentFolder = folderName),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              // Folder icon — 与文件图标容器完全一致
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.folder_outlined, size: 22, color: Colors.amber),
                ),
              ),
              // Folder info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FileManifest.getFolderBaseName(folderName),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _folderDetailText(folderName, fileCount),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Popup menu — 和文件完全一致
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _renameFolder(folderName);
                    case 'move':
                      _moveFolder(folderName);
                    case 'copy':
                      _copyFolder(folderName);
                    case 'delete':
                      _deleteFolder(folderName);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('重命名'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'move', child: ListTile(leading: Icon(Icons.drive_file_move, size: 20), title: Text('移动'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy, size: 20), title: Text('复制'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 20, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
