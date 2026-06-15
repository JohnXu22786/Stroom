import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/image_manifest.dart';

/// Shows a dialog for selecting images from the app's internal album.
///
/// 保留文件层级样式，支持文件夹导航、跨文件夹多选，
/// 底部显示选中图片的缩略图预览。
/// Returns a list of (fileName, data) entries for the selected images,
/// or null if the user cancels.
Future<List<MapEntry<String, Uint8List>>?> showAppAlbumPickerDialog(
  BuildContext context,
) {
  return showDialog<List<MapEntry<String, Uint8List>>?>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => const _AppAlbumPickerDialog(),
  );
}

class _AppAlbumPickerDialog extends ConsumerStatefulWidget {
  const _AppAlbumPickerDialog();

  @override
  ConsumerState<_AppAlbumPickerDialog> createState() =>
      _AppAlbumPickerDialogState();
}

class _AppAlbumPickerDialogState
    extends ConsumerState<_AppAlbumPickerDialog> {
  List<ImageRecord> _records = [];
  Set<String> _folders = {};
  bool _loading = true;
  String _currentFolder = '';

  // 多选状态: key = recordId, value = (fileName, bytes)
  final Map<String, MapEntry<String, Uint8List>> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await ref.read(imageRecordsProvider.notifier).loadRecords();
      await ref.read(imageFolderListProvider.notifier).loadFolders();
      final records = ref.read(imageRecordsProvider);
      final folders = ref.read(imageFolderListProvider);
      if (mounted) {
        setState(() {
          _records = List<ImageRecord>.from(records);
          _folders = Set<String>.from(folders);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _isRoot => _currentFolder.isEmpty;

  List<String> get _subFolders {
    return FolderPathUtils.getChildFolderPaths(_currentFolder, _folders)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<ImageRecord> get _currentFiles {
    return _records
        .where((r) => _isRoot ? r.folder.isEmpty : r.folder == _currentFolder)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _navigateToFolder(String folder) {
    setState(() => _currentFolder = folder);
  }

  void _navigateBack() {
    final parent = FolderPathUtils.getParentFolderPath(_currentFolder);
    setState(() => _currentFolder = parent);
  }

  bool _isSelected(String recordId) => _selectedItems.containsKey(recordId);

  Future<void> _toggleSelection(ImageRecord record) async {
    final key = record.id;
    if (_selectedItems.containsKey(key)) {
      setState(() => _selectedItems.remove(key));
      return;
    }

    // 读取文件数据
    Uint8List? data;
    try {
      data = await ImageManifest.readFile(record.storagePath);
    } catch (_) {}
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
      }
      return;
    }

    final fileName = '${record.name}.${record.format}';
    setState(() {
      _selectedItems[key] = MapEntry(fileName, data!);
    });
  }

  void _clearSelection() {
    setState(() => _selectedItems.clear());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = _selectedItems.isNotEmpty;

    return PopScope(
      canPop: _isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isRoot) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('应用内相册'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          if (hasSelection)
            TextButton(
              key: const Key('album_picker_clear_btn'),
              onPressed: _clearSelection,
              child: Text(
                '清除 (${_selectedItems.length})',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Folder path indicator
          if (!_isRoot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 14,
                      color: cs.primary.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _currentFolder,
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

          // Content
          Expanded(
            child: _buildContent(cs),
          ),

          // Preview bar
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
                key: const Key('album_picker_confirm_btn'),
                onPressed: () {
                  final result = _selectedItems.values.toList();
                  Navigator.of(context).pop(result);
                },
                icon: const Icon(Icons.check, size: 18),
                label: Text(hasSelection
                    ? '确定 (${_selectedItems.length})'
                    : '确定'),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final subFolders = _subFolders;
    final files = _currentFiles;
    final hasContent = subFolders.isNotEmpty || files.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRoot ? Icons.folder_outlined : Icons.folder_open_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isRoot ? '暂无图片' : '此文件夹为空',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        // Back item
        if (!_isRoot) _buildBackItem(cs),

        // Folders
        for (final folder in subFolders) _buildFolderItem(cs, folder),

        // Files
        ...files.map((r) => _buildImageItem(cs, r)),
      ],
    );
  }

  Widget _buildBackItem(ColorScheme cs) {
    final parent = FolderPathUtils.getParentFolderPath(_currentFolder);
    return Card(
      key: const Key('album_picker_back_item'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: _navigateBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                parent.isEmpty
                    ? '返回根目录'
                    : '返回: ${FolderPathUtils.getFolderBaseName(parent)}',
                style: const TextStyle(fontSize: 15, color: Colors.blue),
              ),
              const Spacer(),
              Text(
                FolderPathUtils.getFolderBaseName(_currentFolder),
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(ColorScheme cs, String folderPath) {
    final baseName = FolderPathUtils.getFolderBaseName(folderPath);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _navigateToFolder(folderPath),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
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

  Widget _buildImageItem(ColorScheme cs, ImageRecord record) {
    final isSelected = _isSelected(record.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _toggleSelection(record),
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
                  onChanged: (_) => _toggleSelection(record),
                ),
              ),
              // Thumbnail
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _AlbumImageThumbnail(record: record),
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
                        if (record.folder.isNotEmpty &&
                            record.folder != _currentFolder) ...[
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
                          _formatSize(record.size),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
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

  // ====================================================================
  // Preview bar
  // ====================================================================

  Widget _buildPreviewBar(ColorScheme cs) {
    final items = _selectedItems.entries.toList();

    return Container(
      key: const Key('album_picker_preview_bar'),
      height: 100,
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
              '已选择 ${items.length} 张图片',
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
                final mapEntry = items[index];
                final entry = mapEntry.value;
                return _AlbumPreviewChip(
                  fileName: entry.key,
                  bytes: entry.value,
                  onRemove: () {
                    setState(() => _selectedItems.remove(mapEntry.key));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ====================================================================
// Album Image Thumbnail
// ====================================================================

class _AlbumImageThumbnail extends StatefulWidget {
  final ImageRecord record;

  const _AlbumImageThumbnail({required this.record});

  @override
  State<_AlbumImageThumbnail> createState() => _AlbumImageThumbnailState();
}

class _AlbumImageThumbnailState extends State<_AlbumImageThumbnail> {
  Future<Uint8List?>? _imageDataFuture;

  @override
  void initState() {
    super.initState();
    _imageDataFuture = _loadImageData();
  }

  @override
  void didUpdateWidget(covariant _AlbumImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.hash != oldWidget.record.hash) {
      _imageDataFuture = _loadImageData();
    }
  }

  Future<Uint8List?> _loadImageData() async {
    final thumb =
        await ImageManifest.readFile('${widget.record.hash}_thumb.png');
    if (thumb != null) return thumb;
    return ImageManifest.readFile(widget.record.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageDataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image, color: Colors.grey, size: 24),
            ),
          );
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
            ),
          ),
        );
      },
    );
  }
}

// ====================================================================
// Preview Chip (same style as app_file_picker_dialog)
// ====================================================================

class _AlbumPreviewChip extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _AlbumPreviewChip({
    required this.fileName,
    required this.bytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Icon(
                Icons.image,
                size: 24,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: cs.onError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
