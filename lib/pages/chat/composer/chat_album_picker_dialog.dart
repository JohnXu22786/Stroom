import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stroom/providers/image_provider.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';

import 'album_picker_shared.dart';

import '../../../widgets/constrained_text.dart';

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

/// Pauses file reads initiated by the picker in focused async lifecycle tests.
@visibleForTesting
Future<void> Function(String fileName)? beforeAppAlbumPickerReadForTesting;

/// Overrides edited-image temp writes in focused async lifecycle tests.
@visibleForTesting
Future<void> Function(File file, Uint8List bytes)?
    beforeAppAlbumPickerTempWriteForTesting;

/// Supplies edited bytes without opening the editor in lifecycle tests.
@visibleForTesting
Future<Uint8List?> Function(String fileName, Uint8List imageBytes)?
    appAlbumPickerEditImageForTesting;

int _appAlbumPickerTempEditCounter = 0;

class _AppAlbumPickerDialog extends ConsumerStatefulWidget {
  const _AppAlbumPickerDialog();

  @override
  ConsumerState<_AppAlbumPickerDialog> createState() =>
      _AppAlbumPickerDialogState();
}

class _AppAlbumPickerDialogState extends ConsumerState<_AppAlbumPickerDialog> {
  List<ImageRecord> _records = [];
  Set<String> _folders = {};
  bool _loading = true;
  bool _loadFailed = false;
  String _currentFolder = '';

  // 多选状态: key = recordId, value = (fileName, bytes)
  final Map<String, MapEntry<String, Uint8List>> _selectedItems = {};
  final Map<String, Object> _editAttempts = {};
  final List<String> _selectionOrder = [];
  final Map<String, Object> _pendingSelections = {};
  final Map<String, Future<void>> _pendingReads = {};
  Completer<void> _pendingSelectionChanged = Completer<void>();
  bool _confirmingSelection = false;
  bool _confirmationFailedRead = false;
  bool _isClosing = false;

  /// Track temp file paths created during edit for cleanup on dialog close.
  final List<String> _tempEditFiles = [];
  final Map<String, Future<void>> _pendingTempEditWrites = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cleanupTempFiles();
    super.dispose();
  }

  /// Clean up any temp edit files written to the cache directory.
  Future<void> _cleanupTempFiles() async {
    final paths = List<String>.of(_tempEditFiles);
    try {
      await Future.wait<void>([
        for (final path in paths)
          if (_pendingTempEditWrites.containsKey(path))
            _pendingTempEditWrites[path]!,
      ]);
    } catch (_) {
      // A failed write can still leave a partial file to remove below.
    }
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Non-critical cleanup
      }
    }
    _tempEditFiles.removeWhere(paths.contains);
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
          _loadFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _retryLoadData() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    await _loadData();
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

  bool _isSelected(String recordId) =>
      _selectedItems.containsKey(recordId) ||
      _pendingSelections.containsKey(recordId);

  int get _selectionCount => _selectedItems.length + _pendingSelections.length;

  List<MapEntry<String, MapEntry<String, Uint8List>>>
      get _orderedSelectedItems {
    return [
      for (final key in _selectionOrder)
        if (_selectedItems.containsKey(key))
          MapEntry(key, _selectedItems[key]!),
    ];
  }

  void _notifyPendingSelectionChanged() {
    final changed = _pendingSelectionChanged;
    _pendingSelectionChanged = Completer<void>();
    changed.complete();
  }

  Future<void> _toggleSelection(ImageRecord record) async {
    final key = record.id;
    if (_selectedItems.containsKey(key)) {
      setState(() {
        _selectedItems.remove(key);
        _editAttempts.remove(key);
        _selectionOrder.remove(key);
      });
      return;
    }
    if (_pendingSelections.containsKey(key)) {
      setState(() {
        _pendingSelections.remove(key);
        _pendingReads.remove(key);
        _selectionOrder.remove(key);
      });
      _notifyPendingSelectionChanged();
      return;
    }

    final token = Object();
    setState(() {
      _pendingSelections[key] = token;
      _selectionOrder.add(key);
    });
    _notifyPendingSelectionChanged();
    final read = _readSelection(record, token);
    _pendingReads[key] = read;
    await read;
  }

  Future<void> _readSelection(ImageRecord record, Object token) async {
    Uint8List? data;
    try {
      await beforeAppAlbumPickerReadForTesting?.call(record.storagePath);
      data = await ImageManifest.readFile(record.storagePath);
    } catch (_) {}

    if (!mounted ||
        _isClosing ||
        !identical(_pendingSelections[record.id], token)) {
      return;
    }

    final hasData = data != null && data.isNotEmpty;
    setState(() {
      _pendingSelections.remove(record.id);
      _pendingReads.remove(record.id);
      if (hasData) {
        _selectedItems[record.id] = MapEntry(
          '${record.name}.${record.format}',
          data!,
        );
      } else {
        _selectionOrder.remove(record.id);
        if (_confirmingSelection) _confirmationFailedRead = true;
      }
    });
    _notifyPendingSelectionChanged();
    if (!hasData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.appMediaUnreadable),
        ),
      );
    }
  }

  void _clearSelection() {
    _cleanupTempFiles();
    setState(() {
      _selectedItems.clear();
      _editAttempts.clear();
      _selectionOrder.clear();
      _pendingSelections.clear();
      _pendingReads.clear();
      _confirmationFailedRead = false;
    });
    _notifyPendingSelectionChanged();
  }

  Future<void> _confirmSelection() async {
    if (_confirmingSelection || _loading || _loadFailed) return;
    setState(() {
      _confirmingSelection = true;
      _confirmationFailedRead = false;
    });
    while (_pendingReads.isNotEmpty) {
      await Future.any<void>([
        Future.wait<void>(List<Future<void>>.of(_pendingReads.values)),
        _pendingSelectionChanged.future,
      ]);
      if (!mounted || _isClosing) return;
    }
    if (!mounted || _isClosing) return;
    if (_confirmationFailedRead) {
      setState(() {
        _confirmingSelection = false;
        _confirmationFailedRead = false;
      });
      return;
    }
    Navigator.of(context)
        .pop(_orderedSelectedItems.map((entry) => entry.value).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasSelection = _selectionCount > 0;

    return PopScope(
      canPop: _isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _isClosing = true;
          _pendingSelections.clear();
          _pendingReads.clear();
          _notifyPendingSelectionChanged();
        } else if (!_isRoot) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: ConstrainedText(
            l10n.chatAlbumPickerTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
                child: ConstrainedText(
                  l10n.appMediaClearSelection(_selectionCount),
                  style: TextStyle(color: cs.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      child: ConstrainedText(
                        _currentFolder,
                        maxLines: 1,
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
                  onPressed: _confirmingSelection || _loading || _loadFailed
                      ? null
                      : _confirmSelection,
                  icon: const Icon(Icons.check, size: 18),
                  label: ConstrainedText(
                    hasSelection
                        ? l10n.appMediaConfirmSelectionCount(_selectionCount)
                        : l10n.appMediaConfirmSelection,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadFailed) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.albumPickerLoadFailed),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('album_picker_retry_btn'),
              onPressed: _retryLoadData,
              child: ConstrainedText(
                l10n.actionRetry,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
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
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isRoot ? l10n.chatAlbumPickerEmpty : l10n.appMediaEmptyFolder,
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
              Icon(Icons.arrow_back, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                parent.isEmpty
                    ? AppLocalizations.of(context)!.appMediaRoot
                    : AppLocalizations.of(context)!.appMediaParentFolder(
                        FolderPathUtils.getFolderBaseName(parent),
                      ),
                style: TextStyle(fontSize: 15, color: cs.primary),
              ),
              const Spacer(),
              Text(
                FolderPathUtils.getFolderBaseName(_currentFolder),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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
                child: ConstrainedText(
                  baseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
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
                    ConstrainedText(
                      '${record.name}.${record.format}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (record.folder.isNotEmpty &&
                            record.folder != _currentFolder) ...[
                          Icon(
                            Icons.folder,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: ConstrainedText(
                              record.folder,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatSize(record.size),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
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
    final items = _orderedSelectedItems;

    return Container(
      key: const Key('album_picker_preview_bar'),
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
              AppLocalizations.of(context)!
                  .appAlbumPickerSelectedImages(_selectionCount),
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
                    setState(() {
                      _selectedItems.remove(mapEntry.key);
                      _editAttempts.remove(mapEntry.key);
                      _selectionOrder.remove(mapEntry.key);
                    });
                  },
                  onTap: () =>
                      _onPreviewChipTap(mapEntry.key, entry.key, entry.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Handle tap on a preview chip: show fullscreen preview with edit.
  /// If the user edits the image, the edited bytes are saved to temp cache
  /// and the selected item is updated in memory (original file is NOT overwritten).
  /// The quick editor processes the image in place and pops back with the
  /// edited bytes only after the pipeline finishes.
  Future<void> _onPreviewChipTap(
    String recordKey,
    String fileName,
    Uint8List imageBytes,
  ) async {
    late final Object editAttempt;
    final editForTesting = appAlbumPickerEditImageForTesting;
    final Uint8List? editedBytes;
    if (editForTesting != null) {
      editAttempt = Object();
      _editAttempts[recordKey] = editAttempt;
      editedBytes = await editForTesting(fileName, imageBytes);
    } else {
      // Show the fullscreen preview dialog with edit button
      final shouldEdit = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            ImagePreviewDialog(imageData: imageBytes, fileName: fileName),
      );

      if (shouldEdit != true || !mounted) return;

      editAttempt = Object();
      _editAttempts[recordKey] = editAttempt;
      // User tapped edit — open quick editor
      editedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtendedImageEditorPage(
            imageBytes: imageBytes,
            fileName: fileName,
          ),
        ),
      );
    }

    final editedImageBytes = editedBytes;
    if (editedImageBytes == null || !mounted) return;

    // Save edited bytes to temp cache directory instead of overwriting original
    String? tempPath;
    try {
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final tempFileName = 'edited_${DateTime.now().millisecondsSinceEpoch}_'
          '${_appAlbumPickerTempEditCounter++}_$fileName';
      final tempFile = File('${tempDir.path}/$tempFileName');
      tempPath = tempFile.path;
      _tempEditFiles.add(tempPath);
      final write = beforeAppAlbumPickerTempWriteForTesting?.call(
            tempFile,
            editedImageBytes,
          ) ??
          tempFile.writeAsBytes(editedImageBytes);
      _pendingTempEditWrites[tempFile.path] = write;
      try {
        await write;
      } finally {
        _pendingTempEditWrites.remove(tempFile.path);
      }
    } catch (_) {
      if (tempPath != null) {
        _tempEditFiles.remove(tempPath);
        try {
          final file = File(tempPath);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Best-effort cleanup of a partial temp file.
        }
      }
      // Temp file save is best-effort; we keep the bytes in memory
    }

    // The picker may have been dismissed, the item removed, or a newer edit
    // started while the temp save was in flight. Only apply the latest edit
    // while its selected entry still exists.
    if (!mounted) return;
    final current = _selectedItems[recordKey];
    if (current == null || !identical(_editAttempts[recordKey], editAttempt)) {
      return;
    }

    // Update the selected item in-memory with edited bytes
    setState(() {
      _selectedItems[recordKey] = MapEntry(fileName, editedImageBytes);
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Keep private alias for backward reference
typedef _AlbumImageThumbnail = AlbumImageThumbnail;
typedef _AlbumPreviewChip = AlbumPreviewChip;
