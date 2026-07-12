import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'file_picker_shared.dart';

// ====================================================================
// Public entry point
// ====================================================================

/// Shows the unified app-internal file picker dialog.
///
/// Supports multi-select across folders and file types, with a bottom
/// preview bar showing image thumbnails and file name chips.
///
/// Returns a list of (fileName, bytes) for selected files, or null if
/// the user cancels.
Future<List<MapEntry<String, Uint8List>>?> showAppFilePickerDialog(
  BuildContext context,
) {
  return showDialog<List<MapEntry<String, Uint8List>>?>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => const _AppFilePickerDialog(),
  );
}

// ====================================================================
// Dialog
// ====================================================================

class _AppFilePickerDialog extends StatefulWidget {
  const _AppFilePickerDialog();

  @override
  State<_AppFilePickerDialog> createState() => _AppFilePickerDialogState();
}

// Keep private alias for backward reference
typedef _TabData = TabData;
typedef _FileTabType = FileTabType;

class _AppFilePickerDialogState extends State<_AppFilePickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Selected items across all tabs: key = "tabType:recordId", value = (fileName, bytes)
  final Map<String, MapEntry<String, Uint8List>> _selectedItems = {};

  /// Track temp file paths created during edit for cleanup on dialog close.
  final List<String> _tempEditFiles = [];

  // Tab data (loaded asynchronously)
  final Map<_FileTabType, _TabData> _tabData = {};
  final Map<_FileTabType, bool> _tabLoading = {};
  final Map<_FileTabType, String> _currentFolders = {};

  static const _tabLabels = <_FileTabType, String>{
    _FileTabType.text: '文本',
    _FileTabType.image: '图片',
    _FileTabType.video: '视频',
    _FileTabType.audio: '音频',
  };

  static const _tabIcons = <_FileTabType, IconData>{
    _FileTabType.text: Icons.description_outlined,
    _FileTabType.image: Icons.image_outlined,
    _FileTabType.video: Icons.videocam_outlined,
    _FileTabType.audio: Icons.audiotrack_outlined,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Load data for all tabs
    for (final type in _FileTabType.values) {
      _tabLoading[type] = true;
      _currentFolders[type] = '';
      _loadTabData(type);
    }
  }

  @override
  void dispose() {
    _cleanupTempFiles();
    _tabController.dispose();
    super.dispose();
  }

  /// Clean up any temp edit files written to the cache directory.
  Future<void> _cleanupTempFiles() async {
    for (final path in _tempEditFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Non-critical cleanup
      }
    }
    _tempEditFiles.clear();
  }

  Future<void> _loadTabData(_FileTabType type) async {
    try {
      List<FileRecord> records;
      Set<String> folders;

      switch (type) {
        case _FileTabType.text:
          final textRecords = await TextManifest.loadRecords();
          records = textRecords.cast<FileRecord>();
          folders = await TextManifest.getAllFolders();
          break;
        case _FileTabType.image:
          final imageRecords = await ImageManifest.loadRecords();
          records = imageRecords.cast<FileRecord>();
          folders = await ImageManifest.getAllFolders();
          break;
        case _FileTabType.video:
          final videoRecords = await VideoManifest.loadRecords();
          records = videoRecords.cast<FileRecord>();
          folders = await VideoManifest.getAllFolders();
          break;
        case _FileTabType.audio:
          final audioRecords = await FileManifest.loadRecords();
          records = audioRecords.cast<FileRecord>();
          folders = await FileManifest.getAllFolders();
          break;
      }

      if (!mounted) return;
      setState(() {
        _tabData[type] = _TabData(
          records: records,
          allFolders: folders,
        );
        _tabLoading[type] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tabData[type] = _TabData(records: [], allFolders: {});
        _tabLoading[type] = false;
      });
    }
  }

  /// Generate a unique key for a selected item: "tabType:recordId"
  String _selectionKey(_FileTabType tabType, String recordId) =>
      '${tabType.index}:$recordId';

  bool _isSelected(_FileTabType tabType, String recordId) =>
      _selectedItems.containsKey(_selectionKey(tabType, recordId));

  void _toggleSelection(
      _FileTabType tabType, String recordId, String fileName, Uint8List bytes) {
    final key = _selectionKey(tabType, recordId);
    setState(() {
      if (_selectedItems.containsKey(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems[key] = MapEntry(fileName, bytes);
      }
    });
  }

  void _clearSelection() {
    _cleanupTempFiles();
    setState(() {
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = _selectedItems.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('选择文件'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          if (hasSelection)
            TextButton(
              key: const Key('file_picker_clear_btn'),
              onPressed: _clearSelection,
              child: Text(
                '清除 (${_selectedItems.length})',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            tabs: _FileTabType.values.map((type) {
              return Tab(
                key: Key('file_picker_tab_${type.name}'),
                icon: Icon(_tabIcons[type]),
                text: _tabLabels[type],
              );
            }).toList(),
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab content
          Expanded(
            key: const Key('file_picker_content'),
            child: TabBarView(
              controller: _tabController,
              children: _FileTabType.values.map((type) {
                return _buildTabContent(type);
              }).toList(),
            ),
          ),

          // Preview bar (bottom)
          if (hasSelection) _buildPreviewBar(cs),

          // Confirm button
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: FilledButton.icon(
                key: const Key('file_picker_confirm_btn'),
                onPressed: () {
                  final result = _selectedItems.values.toList();
                  Navigator.of(context).pop(result);
                },
                icon: const Icon(Icons.check, size: 18),
                label:
                    Text(hasSelection ? '确定 (${_selectedItems.length})' : '确定'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // Tab content builder
  // ====================================================================

  Widget _buildTabContent(_FileTabType type) {
    final cs = Theme.of(context).colorScheme;
    final loading = _tabLoading[type] ?? true;
    final data = _tabData[type];

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data == null) {
      return const Center(child: Text('加载失败'));
    }

    final currentFolder = _currentFolders[type] ?? '';
    final isRoot = currentFolder.isEmpty;

    // Get direct subfolders
    final subFolders = FolderPathUtils.getChildFolderPaths(
      currentFolder,
      data.allFolders,
    );
    subFolders.sort();

    // Get files in current folder
    final currentFiles = data.records.where((r) {
      return isRoot ? r.folder.isEmpty : r.folder == currentFolder;
    }).toList();

    // Sort by name
    currentFiles
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final hasContent = subFolders.isNotEmpty || currentFiles.isNotEmpty;

    return Column(
      key: const Key('file_picker_tab_content'),
      children: [
        // Folder path indicator
        if (!isRoot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.folder,
                    size: 14, color: cs.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    currentFolder,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // File list
        Expanded(
          child: !hasContent
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_outlined,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isRoot ? '暂无文件' : '此文件夹为空',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    // Back button (when in subfolder)
                    if (!isRoot) _buildBackItem(type, currentFolder),

                    // Subfolders
                    for (final folder in subFolders)
                      _buildFolderItem(type, folder, currentFolder),

                    // Files
                    for (final record in currentFiles)
                      _buildFileItem(type, record),
                  ],
                ),
        ),
      ],
    );
  }

  // ====================================================================
  // Folder navigation
  // ====================================================================

  Widget _buildBackItem(_FileTabType type, String currentFolder) {
    final parentFolder = FolderPathUtils.getParentFolderPath(currentFolder);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentFolders[type] = parentFolder;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                parentFolder.isEmpty
                    ? '返回根目录'
                    : '返回: ${FolderPathUtils.getFolderBaseName(parentFolder)}',
                style: TextStyle(fontSize: 15, color: Colors.blue[700]),
              ),
              const Spacer(),
              Text(
                FolderPathUtils.getFolderBaseName(currentFolder),
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(
      _FileTabType type, String folderPath, String currentFolder) {
    final baseName = FolderPathUtils.getFolderBaseName(folderPath);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentFolders[type] = folderPath;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.folder_outlined,
                      size: 22, color: Colors.amber),
                ),
              ),
              Expanded(
                child: Text(
                  baseName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // File item
  // ====================================================================

  Widget _buildFileItem(_FileTabType type, FileRecord record) {
    final isSelected = _isSelected(type, record.id);
    final isImage = type == _FileTabType.image;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          _onFileTap(type, record);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _onFileTap(type, record),
                ),
              ),
              // File icon / thumbnail
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isImage
                      ? null
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: isImage ? Clip.antiAlias : Clip.none,
                child: isImage
                    ? _buildImageThumbnail(record)
                    : type == _FileTabType.video
                        ? _buildVideoThumbnail(record as VideoRecord)
                        : _buildFileIcon(record),
              ),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.name}.${record.format}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (record.folder.isNotEmpty) ...[
                          Icon(Icons.folder, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              record.folder,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[400]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                color: Colors.grey[400]!,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          formatFileSize(record.size),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onFileTap(_FileTabType type, FileRecord record) async {
    // Read file bytes
    Uint8List? bytes;
    try {
      bytes = await _readFileBytes(type, record);
    } catch (_) {}
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
      }
      return;
    }
    final fileName = '${record.name}.${record.format}';
    _toggleSelection(type, record.id, fileName, bytes);
  }

  Future<Uint8List?> _readFileBytes(
      _FileTabType type, FileRecord record) async {
    switch (type) {
      case _FileTabType.text:
        return TextManifest.readFile((record as TextRecord).storagePath);
      case _FileTabType.image:
        return ImageManifest.readFile((record as ImageRecord).storagePath);
      case _FileTabType.video:
        return VideoManifest.readFile((record as VideoRecord).storagePath);
      case _FileTabType.audio:
        return FileManifest.readFile((record as AudioRecord).storagePath);
    }
  }

  // ====================================================================
  // Thumbnail & Icon helpers
  // ====================================================================

  Widget _buildImageThumbnail(FileRecord record) {
    final imgRecord = record as ImageRecord;
    return FutureBuilder<Uint8List?>(
      future: () async {
        // Try reading thumbnail file from disk first
        final thumb =
            await ImageManifest.readFile('${imgRecord.hash}_thumb.png');
        if (thumb != null && thumb.isNotEmpty) return thumb;
        // Fall back to full image
        return ImageManifest.readFile(imgRecord.storagePath);
      }(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return ExtendedImage.memory(
            data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.failed) {
                return _defaultIcon();
              }
              return null;
            },
          );
        }
        return _defaultIcon();
      },
    );
  }

  Widget _buildVideoThumbnail(VideoRecord record) {
    return FutureBuilder<Uint8List?>(
      future: VideoManifest.readThumbnail(record.hash),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildFileIcon(record),
            ),
          );
        }
        return _buildFileIcon(record);
      },
    );
  }

  Widget _buildFileIcon(FileRecord record) {
    IconData icon;
    Color color;

    switch (record.runtimeType) {
      case TextRecord _:
        icon = Icons.description_outlined;
        color = Colors.blue;
      case VideoRecord _:
        icon = Icons.videocam_outlined;
        color = Colors.red;
      case AudioRecord _:
        icon = Icons.audiotrack_outlined;
        color = Colors.green;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = Colors.grey;
    }

    return Center(
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _defaultIcon() {
    return Center(
      child: Icon(Icons.image, color: Colors.grey[400], size: 22),
    );
  }

  // ====================================================================
  // Preview bar
  // ====================================================================

  Widget _buildPreviewBar(ColorScheme cs) {
    final items = _selectedItems.values.toList();

    return Container(
      key: const Key('file_picker_preview_bar'),
      height: 106,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Text(
              '已选择 ${items.length} 个文件',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                final isImage = isImageFileByExtension(entry.key);
                return PreviewChip(
                  fileName: entry.key,
                  bytes: entry.value,
                  isImage: isImage,
                  onRemove: () {
                    // Find which key this entry corresponds to
                    final key = _selectedItems.entries
                        .firstWhere((e) => e.value == entry)
                        .key;
                    setState(() {
                      _selectedItems.remove(key);
                    });
                  },
                  onTap: isImage
                      ? () => _onPreviewImageTap(entry.key, entry.value)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Handle tap on an image preview chip: show fullscreen preview with edit.
  /// Edited bytes are saved to temp cache (original file NOT overwritten).
  Future<void> _onPreviewImageTap(String fileName, Uint8List imageBytes) async {
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) => ImagePreviewDialog(
        imageData: imageBytes,
        fileName: fileName,
      ),
    );

    if (shouldEdit != true || !mounted) return;

    final editedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => ExtendedImageEditorPage(
          imageBytes: imageBytes,
          fileName: fileName,
        ),
      ),
    );

    if (editedBytes == null || !mounted) return;

    // Save edited bytes to temp cache directory (do NOT overwrite original)
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFileName =
          'edited_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final tempFile = File('${tempDir.path}/$tempFileName');
      await tempFile.writeAsBytes(editedBytes);
      _tempEditFiles.add(tempFile.path);
    } catch (_) {
      // Temp file save is best-effort; keep bytes in memory
    }

    // Update the selected item in-memory with edited bytes
    try {
      final key = _selectedItems.entries
          .firstWhere((e) => e.value == MapEntry(fileName, imageBytes))
          .key;
      if (mounted) {
        setState(() {
          _selectedItems[key] = MapEntry(fileName, editedBytes);
        });
      }
    } catch (_) {
      // Item was removed while editor was open — silently ignore
    }
  }
}
