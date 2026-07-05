import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/folder_path_utils.dart';

import 'media_picker_config.dart';

// ============================================================================
// Public API
// ============================================================================

/// Shows a unified media picker dialog for selecting files from the app's
/// internal storage.
///
/// Returns a list of (fileName, bytes) entries for the selected files,
/// or null if the user cancels.
///
/// In single-select mode (default), the list will contain at most one entry.
/// In multi-select mode, the list may contain multiple entries.
Future<List<MapEntry<String, Uint8List>>?> showMediaPickerDialog<T>(
  BuildContext context,
  MediaPickerConfig<T> config,
) {
  return showDialog<List<MapEntry<String, Uint8List>>?>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => _AppMediaPickerDialog<T>(config: config),
  );
}

// ============================================================================
// Internal dialog widget
// ============================================================================

class _AppMediaPickerDialog<T> extends StatefulWidget {
  final MediaPickerConfig<T> config;

  const _AppMediaPickerDialog({required this.config});

  @override
  State<_AppMediaPickerDialog<T>> createState() =>
      _AppMediaPickerDialogState<T>();
}

class _AppMediaPickerDialogState<T> extends State<_AppMediaPickerDialog<T>> {
  List<T> _records = [];
  Set<String> _folders = {};
  bool _loading = true;
  String _currentFolder = '';

  // Multi-selection state: key = recordId, value = (fileName, bytes)
  final Map<String, MapEntry<String, Uint8List>> _selectedItems = {};

  /// Guard flag to prevent double [Navigator.pop] calls (e.g., rapid taps).
  bool _resultDelivered = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final records = await widget.config.loadRecords();
      final folders = await widget.config.loadFolders();
      if (mounted) {
        setState(() {
          _records = List<T>.from(records);
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

  List<T> get _currentFiles {
    return _records
        .where(
          (r) =>
              _isRoot ? _getFolder(r).isEmpty : _getFolder(r) == _currentFolder,
        )
        .toList()
      ..sort(
        (a, b) => widget.config
            .displayName(a)
            .toLowerCase()
            .compareTo(widget.config.displayName(b).toLowerCase()),
      );
  }

  String _getFolder(T record) {
    // Use the folderPath getter if available via reflection.
    // We use dynamic access since T is generic.
    // All our record types (ImageRecord, AudioRecord, VideoRecord) have a
    // `folder` field.
    final dynamic r = record;
    return (r.folder as String?) ?? '';
  }

  String _getRecordId(T record) {
    final dynamic r = record;
    return (r.id as String?) ?? '';
  }

  void _navigateToFolder(String folder) {
    setState(() => _currentFolder = folder);
  }

  void _navigateBack() {
    final parent = FolderPathUtils.getParentFolderPath(_currentFolder);
    setState(() => _currentFolder = parent);
  }

  bool _isSelected(String recordId) => _selectedItems.containsKey(recordId);

  Future<void> _toggleSelection(T record) async {
    final key = _getRecordId(record);
    if (_selectedItems.containsKey(key)) {
      setState(() => _selectedItems.remove(key));
      return;
    }

    // Read the file data
    Uint8List? readData;
    try {
      readData = await widget.config.readFile(record);
    } catch (_) {}
    if (readData == null || readData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
      }
      return;
    }

    final data = readData;
    final fileName = widget.config.displayName(record);

    if (!widget.config.multiSelect) {
      // Single-select: close immediately with the result
      if (mounted && !_resultDelivered) {
        _resultDelivered = true;
        Navigator.of(context).pop([MapEntry(fileName, data)]);
      }
      return;
    }

    setState(() {
      _selectedItems[key] = MapEntry(fileName, data);
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
          title: Text(widget.config.title),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (!_resultDelivered) {
                _resultDelivered = true;
                Navigator.of(context).pop(null);
              }
            },
          ),
          actions: [
            if (widget.config.multiSelect && hasSelection)
              TextButton(
                key: const Key('media_picker_clear_btn'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
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
            Expanded(child: _buildContent(cs)),

            // Preview bar (multi-select only)
            if (widget.config.multiSelect && hasSelection) _buildPreviewBar(cs),

            // Confirm button (multi-select only)
            if (widget.config.multiSelect)
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
                    key: const Key('media_picker_confirm_btn'),
                    onPressed: _resultDelivered
                        ? null
                        : () {
                            _resultDelivered = true;
                            final result = _selectedItems.values.toList();
                            Navigator.of(context).pop(result);
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      hasSelection ? '确定 (${_selectedItems.length})' : '确定',
                    ),
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
              _isRoot ? widget.config.emptyIcon : Icons.folder_open_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isRoot ? widget.config.emptyText : '此文件夹为空',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
        ...files.map((r) => _buildFileItem(cs, r)),
      ],
    );
  }

  Widget _buildBackItem(ColorScheme cs) {
    final parent = FolderPathUtils.getParentFolderPath(_currentFolder);
    return Card(
      key: const Key('media_picker_back_item'),
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
                  child: Icon(
                    Icons.folder_outlined,
                    size: 22,
                    color: Colors.amber,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  baseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
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

  Widget _buildFileItem(ColorScheme cs, T record) {
    final recordId = _getRecordId(record);
    final isSelected = _isSelected(recordId);
    final showCheckbox = widget.config.multiSelect;

    final iconColor = widget.config.fileIconColor ?? cs.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _toggleSelection(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              // Checkbox (multi-select only)
              if (showCheckbox)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(record),
                  ),
                ),
              // File icon
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    widget.config.fileIcon,
                    size: 22,
                    color: iconColor,
                  ),
                ),
              ),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.displayName(record),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    widget.config.subtitleBuilder(record),
                  ],
                ),
              ),
              if (!showCheckbox)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // Preview bar (multi-select only)
  // ====================================================================

  Widget _buildPreviewBar(ColorScheme cs) {
    final items = _selectedItems.entries.toList();

    return Container(
      key: const Key('media_picker_preview_bar'),
      height: 106,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
                final mapEntry = items[index];
                final entry = mapEntry.value;
                return _PreviewChip(
                  label: entry.key,
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
}

// ====================================================================
// Preview chip for the preview bar
// ====================================================================

class _PreviewChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _PreviewChip({required this.label, required this.onRemove});

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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
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
                child: Icon(Icons.close, size: 12, color: cs.onError),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
