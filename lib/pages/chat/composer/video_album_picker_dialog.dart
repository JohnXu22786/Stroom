import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/video_manifest.dart';

/// Result from the video picker containing both the record and its data bytes.
class VideoPickerResult {
  final VideoRecord record;
  final Uint8List bytes;

  const VideoPickerResult({required this.record, required this.bytes});
}

/// Shows a dialog for selecting videos from the app's internal album.
///
/// Supports folder navigation and single selection.
/// Returns the selected [VideoPickerResult], or null if the user cancels.
Future<VideoPickerResult?> showAppVideoPickerDialog(
  BuildContext context,
) {
  return showDialog<VideoPickerResult>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => const _AppVideoPickerDialog(),
  );
}

class _AppVideoPickerDialog extends StatefulWidget {
  const _AppVideoPickerDialog();

  @override
  State<_AppVideoPickerDialog> createState() => _AppVideoPickerDialogState();
}

class _AppVideoPickerDialogState extends State<_AppVideoPickerDialog> {
  List<VideoRecord> _records = [];
  Set<String> _folders = {};
  bool _loading = true;
  String _currentFolder = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      VideoManifest.invalidateCache();
      final records = await VideoManifest.loadRecords();
      final folders = await VideoManifest.getAllFolders();
      if (mounted) {
        setState(() {
          _records = List<VideoRecord>.from(records);
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

  List<VideoRecord> get _currentFiles {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          title: const Text('选择应用内视频'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ),
        body: Column(
          children: [
            // Folder path indicator
            if (!_isRoot)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 14,
                        color: cs.primary.withValues(alpha: 0.7)),
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
              _isRoot ? Icons.video_library_outlined : Icons.folder_open_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isRoot ? '暂无视频' : '此文件夹为空',
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
        ...files.map((r) => _buildVideoItem(cs, r)),
      ],
    );
  }

  Widget _buildBackItem(ColorScheme cs) {
    final parent = FolderPathUtils.getParentFolderPath(_currentFolder);
    return Card(
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

  Widget _buildVideoItem(ColorScheme cs, VideoRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _selectVideo(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              // Video icon
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.videocam,
                      size: 22, color: Colors.indigo),
                ),
              ),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          record.format.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
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
                        Text(
                          _formatSize(record.size),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (record.duration > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                color: Colors.grey[400]!,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(record.duration),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                        if (record.folder.isNotEmpty &&
                            record.folder != _currentFolder) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                color: Colors.grey[400]!,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
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
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectVideo(VideoRecord record) async {
    // Read the file bytes and return them with the record
    try {
      final bytes = await VideoManifest.readFile(record.storagePath);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取视频文件')),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(VideoPickerResult(record: record, bytes: bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取视频失败: $e')),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    if (seconds < 60) return '${seconds}秒';
    if (seconds < 3600) return '${seconds ~/ 60}分${seconds % 60}秒';
    return '${seconds ~/ 3600}时${(seconds % 3600) ~/ 60}分';
  }
}
