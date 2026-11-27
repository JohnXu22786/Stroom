import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';

import 'file_picker_shared.dart';

import '../../../widgets/constrained_text.dart';

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
  BuildContext context, {
  Future<void> Function(String path, Uint8List bytes)? tempFileWriter,
  Future<Directory> Function()? tempDirectoryProvider,
  VoidCallback? onTempFileCleanupComplete,
}) {
  return showDialog<List<MapEntry<String, Uint8List>>?>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => _AppFilePickerDialog(
      tempFileWriter: tempFileWriter,
      tempDirectoryProvider: tempDirectoryProvider,
      onTempFileCleanupComplete: onTempFileCleanupComplete,
    ),
  );
}

// ====================================================================
// Dialog
// ====================================================================

class _AppFilePickerDialog extends StatefulWidget {
  const _AppFilePickerDialog({
    this.tempFileWriter,
    this.tempDirectoryProvider,
    this.onTempFileCleanupComplete,
  });

  final Future<void> Function(String path, Uint8List bytes)? tempFileWriter;
  final Future<Directory> Function()? tempDirectoryProvider;
  final VoidCallback? onTempFileCleanupComplete;

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
  int _selectionGeneration = 0;
  final Map<String, int> _pendingReadGenerationByKey = {};
  final Map<String, Object> _pendingReadTokens = {};
  int _pendingReadCount = 0;

  /// Track temp file paths created during edit for cleanup on dialog close.
  final List<String> _tempEditFiles = [];
  final Set<Future<void>> _pendingTempFileWrites = {};

  // Tab data (loaded asynchronously)
  final Map<_FileTabType, _TabData> _tabData = {};
  final Map<_FileTabType, bool> _tabLoading = {};
  final Map<_FileTabType, String> _currentFolders = {};

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
    final onCleanupComplete = widget.onTempFileCleanupComplete;
    final writesToFinish = List<Future<void>>.of(_pendingTempFileWrites);
    final filesToDelete = List<String>.of(_tempEditFiles);
    await Future.wait(writesToFinish);
    for (final path in filesToDelete) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        _tempEditFiles.remove(path);
      } catch (_) {
        // Keep failed paths tracked so a later cleanup can retry them.
      }
    }
    onCleanupComplete?.call();
  }

  Future<void> _loadTabData(_FileTabType type) async {
    try {
      List<FileRecord> records;
      Set<String> folders;

      switch (type) {
        case _FileTabType.text:
          final textRecords = await TextManifest.loadRecordsStrict();
          records = textRecords.cast<FileRecord>();
          folders = await TextManifest.getAllFolders();
          break;
        case _FileTabType.image:
          final imageRecords = await ImageManifest.loadRecordsStrict();
          records = imageRecords.cast<FileRecord>();
          folders = await ImageManifest.getAllFolders();
          break;
        case _FileTabType.video:
          final videoRecords = await VideoManifest.loadRecordsStrict();
          records = videoRecords.cast<FileRecord>();
          folders = await VideoManifest.getAllFolders();
          break;
        case _FileTabType.audio:
          final audioRecords = await FileManifest.loadRecordsStrict();
          records = audioRecords.cast<FileRecord>();
          folders = await FileManifest.getAllFolders();
          break;
      }

      if (!mounted) return;
      setState(() {
        _tabData[type] = _TabData(records: records, allFolders: folders);
        _tabLoading[type] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep data absent so the tab renders its load-failure state.
        _tabLoading[type] = false;
      });
    }
  }

  /// Generate a unique key for a selected item: "tabType:recordId"
  String _selectionKey(_FileTabType tabType, String recordId) =>
      '${tabType.index}:$recordId';

  bool _isSelected(_FileTabType tabType, String recordId) =>
      _selectedItems.containsKey(_selectionKey(tabType, recordId));

  String _tabLabel(AppLocalizations l10n, _FileTabType type) => switch (type) {
        _FileTabType.text => l10n.chatFilePickerTabText,
        _FileTabType.image => l10n.chatFilePickerTabImages,
        _FileTabType.video => l10n.chatFilePickerTabVideos,
        _FileTabType.audio => l10n.chatFilePickerTabAudio,
      };

  void _toggleSelection(
    _FileTabType tabType,
    String recordId,
    String fileName,
    Uint8List bytes,
  ) {
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
    _selectionGeneration++;
    _cleanupTempFiles();
    _pendingReadTokens.clear();
    setState(() {
      _selectedItems.clear();
      _pendingReadCount = 0;
    });
  }

  /// The tab currently visible to the user.
  _FileTabType get _activeTabType => _FileTabType.values[_tabController.index];

  /// Whether the active tab is showing the root folder (no parent to
  /// navigate up to).
  bool get _isRoot => (_currentFolders[_activeTabType] ?? '').isEmpty;

  /// Navigate [type]'s folder view up one level.
  void _navigateUp(_FileTabType type) {
    final parentFolder = FolderPathUtils.getParentFolderPath(
      _currentFolders[type] ?? '',
    );
    setState(() {
      _currentFolders[type] = parentFolder;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasSelection = _selectedItems.isNotEmpty;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final expandedChrome =
        textScale >= 2 && MediaQuery.sizeOf(context).width <= 600;
    final tabLabelStyle = Theme.of(context).textTheme.labelLarge;
    final standardExpandedTabRowHeight =
        ((tabLabelStyle?.fontSize ?? 14) * textScale * 1.35 + 8)
            .clamp(64.0, 80.0)
            .toDouble();
    final standardClearRowHeight =
        ((tabLabelStyle?.fontSize ?? 14) * textScale * 1.5 + 16)
            .clamp(56.0, 100.0)
            .toDouble();
    const previewBarHeight = 106.0;
    const confirmationBarHeight = kMinInteractiveDimension + 16.0;
    final mediaSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final estimatedBodyHeight = mediaSize.height -
        viewPadding.top -
        viewPadding.bottom -
        kToolbarHeight -
        standardExpandedTabRowHeight * 2 -
        (hasSelection ? standardClearRowHeight : 0) -
        (hasSelection ? previewBarHeight : 0) -
        confirmationBarHeight;
    final shortViewportChrome = expandedChrome && estimatedBodyHeight < 96;
    final expandedTabRowHeight =
        shortViewportChrome ? 56.0 : standardExpandedTabRowHeight;
    final clearRowHeight = shortViewportChrome ? 56.0 : standardClearRowHeight;
    final maxShortViewportRows = _tabData.values.fold<int>(1, (largest, data) {
      final rows = data.records.length + data.allFolders.length + 1;
      return max(largest, rows);
    });
    final shortViewportTabContentHeight = max(
      200.0,
      maxShortViewportRows * 112.0 + 48,
    ).toDouble();
    final tabBarView = TabBarView(
      controller: _tabController,
      children: _FileTabType.values
          .map(
            (type) => _buildTabContent(
              type,
              shortViewport: shortViewportChrome,
            ),
          )
          .toList(),
    );
    final confirmationButton = SafeArea(
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
          onPressed: _pendingReadCount > 0
              ? null
              : () {
                  final result = _selectedItems.values.toList();
                  Navigator.of(context).pop(result);
                },
          icon: const Icon(Icons.check, size: 18),
          label: ConstrainedText(
            hasSelection
                ? l10n.appMediaConfirmSelectionCount(_selectedItems.length)
                : l10n.appMediaConfirmSelection,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    return PopScope(
      // System back inside a subfolder navigates up one level; only at
      // the root does it close the picker (mirrors _AppMediaPickerDialog).
      canPop: _isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isRoot) {
          _navigateUp(_activeTabType);
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: ConstrainedText(
            l10n.chatFilePickerTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          actions: [
            if (hasSelection && !expandedChrome)
              TextButton(
                key: const Key('file_picker_clear_btn'),
                onPressed: _clearSelection,
                child: ConstrainedText(
                  l10n.appMediaClearSelection(_selectedItems.length),
                  style: TextStyle(color: cs.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              (expandedChrome ? expandedTabRowHeight * 2 : 48) +
                  (expandedChrome && hasSelection ? clearRowHeight : 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expandedChrome && hasSelection)
                  SizedBox(
                    height: clearRowHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('file_picker_clear_btn'),
                        onPressed: _clearSelection,
                        child: ConstrainedText(
                          l10n.appMediaClearSelection(_selectedItems.length),
                          style: TextStyle(color: cs.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                if (expandedChrome)
                  _buildExpandedTabBar(
                    l10n,
                    cs,
                    tabLabelStyle,
                    rowHeight: expandedTabRowHeight,
                  )
                else
                  TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    tabs: _FileTabType.values.map((type) {
                      return Tab(
                        key: Key('file_picker_tab_${type.name}'),
                        icon: Icon(_tabIcons[type]),
                        child: ConstrainedText(
                          _tabLabel(l10n, type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        body: shortViewportChrome
            ? SingleChildScrollView(
                key: const Key('file_picker_short_viewport_scroll'),
                child: Column(
                  children: [
                    SizedBox(
                      key: const Key('file_picker_content'),
                      height: shortViewportTabContentHeight,
                      child: tabBarView,
                    ),
                    if (hasSelection) _buildPreviewBar(cs),
                    confirmationButton,
                  ],
                ),
              )
            : Column(
                children: [
                  // Tab content
                  Expanded(
                    key: const Key('file_picker_content'),
                    child: tabBarView,
                  ),

                  // Preview bar (bottom)
                  if (hasSelection) _buildPreviewBar(cs),

                  // Confirm button
                  confirmationButton,
                ],
              ),
      ),
    );
  }

  Widget _buildExpandedTabBar(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextStyle? labelStyle, {
    required double rowHeight,
  }) {
    return Semantics(
      role: SemanticsRole.tabBar,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++)
            SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  for (var column = 0; column < 2; column++)
                    Expanded(
                      child: _buildExpandedTab(
                        row * 2 + column,
                        l10n,
                        colorScheme,
                        labelStyle,
                        rowHeight: rowHeight,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedTab(
    int index,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextStyle? labelStyle, {
    required double rowHeight,
  }) {
    final type = _FileTabType.values[index];
    final selected = _tabController.index == index;
    final label = _tabLabel(l10n, type);
    final foregroundColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: rowHeight,
      width: double.infinity,
      child: Semantics(
        role: SemanticsRole.tab,
        label: label,
        selected: selected,
        onTap: () => _tabController.animateTo(index),
        child: InkWell(
          key: Key('file_picker_tab_${type.name}'),
          onTap: () => _tabController.animateTo(index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Center(
                child: ExcludeSemantics(
                  child: ConstrainedText(
                    label,
                    style: labelStyle?.copyWith(color: foregroundColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // Tab content builder
  // ====================================================================

  Widget _buildTabContent(
    _FileTabType type, {
    required bool shortViewport,
  }) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final loading = _tabLoading[type] ?? true;
    final data = _tabData[type];

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data == null) {
      return Center(child: Text(l10n.chatFilePickerLoadFailed));
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
    currentFiles.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final hasContent = subFolders.isNotEmpty || currentFiles.isNotEmpty;
    final listItems = <Widget>[
      // Back button (when in subfolder)
      if (!isRoot) _buildBackItem(type, currentFolder),

      // Subfolders
      for (final folder in subFolders)
        _buildFolderItem(type, folder, currentFolder),

      // Files
      for (final record in currentFiles) _buildFileItem(type, record),
    ];
    final emptyState = Center(
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
            isRoot ? l10n.chatFilePickerEmpty : l10n.appMediaEmptyFolder,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );

    return Column(
      key: Key('file_picker_tab_content_${type.name}'),
      children: [
        // Folder path indicator
        if (!isRoot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    currentFolder,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // In the short viewport path, the enclosing dialog body owns the one
        // vertical scroll position. Keeping this list non-scrollable lets
        // gestures reach the preview and confirmation below it.
        if (shortViewport)
          if (!hasContent)
            SizedBox(height: 200, child: emptyState)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: listItems,
              ),
            )
        else
          Expanded(
            child: !hasContent
                ? emptyState
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: listItems,
                  ),
          ),
      ],
    );
  }

  // ====================================================================
  // Folder navigation
  // ====================================================================

  Widget _buildBackItem(_FileTabType type, String currentFolder) {
    final cs = Theme.of(context).colorScheme;
    final parentFolder = FolderPathUtils.getParentFolderPath(currentFolder);
    return Card(
      key: const Key('file_picker_back_item'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _navigateUp(type),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedText(
                  parentFolder.isEmpty
                      ? AppLocalizations.of(context)!.appMediaRoot
                      : AppLocalizations.of(context)!.appMediaParentFolder(
                          FolderPathUtils.getFolderBaseName(parentFolder),
                        ),
                  style: TextStyle(fontSize: 15, color: cs.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ConstrainedText(
                    FolderPathUtils.getFolderBaseName(currentFolder),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(
    _FileTabType type,
    String folderPath,
    String currentFolder,
  ) {
    final cs = Theme.of(context).colorScheme;
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

  // ====================================================================
  // File item
  // ====================================================================

  Widget _buildFileItem(_FileTabType type, FileRecord record) {
    final cs = Theme.of(context).colorScheme;
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
                        if (record.folder.isNotEmpty) ...[
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
                          formatFileSize(record.size),
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

  void _onFileTap(_FileTabType type, FileRecord record) async {
    final key = _selectionKey(type, record.id);
    if (_selectedItems.containsKey(key)) {
      setState(() {
        _selectedItems.remove(key);
        _pendingReadGenerationByKey[key] =
            (_pendingReadGenerationByKey[key] ?? 0) + 1;
      });
      return;
    }
    if (_pendingReadTokens.containsKey(key)) return;

    final selectionGeneration = _selectionGeneration;
    final pendingReadGeneration = _pendingReadGenerationByKey[key] ?? 0;
    final pendingReadToken = Object();
    _pendingReadTokens[key] = pendingReadToken;
    setState(() {
      _pendingReadCount++;
    });

    try {
      // Read file bytes
      Uint8List? bytes;
      try {
        bytes = await _readFileBytes(type, record);
      } catch (_) {}
      if (!mounted ||
          selectionGeneration != _selectionGeneration ||
          pendingReadGeneration != (_pendingReadGenerationByKey[key] ?? 0)) {
        return;
      }
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appMediaUnreadable),
          ),
        );
        return;
      }
      final fileName = '${record.name}.${record.format}';
      _toggleSelection(type, record.id, fileName, bytes);
    } finally {
      if (identical(_pendingReadTokens[key], pendingReadToken)) {
        _pendingReadTokens.remove(key);
      }
      if (mounted && selectionGeneration == _selectionGeneration) {
        setState(() {
          _pendingReadCount--;
        });
      }
    }
  }

  Future<Uint8List?> _readFileBytes(
    _FileTabType type,
    FileRecord record,
  ) async {
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
      future: ImageThumbnailLoader.loadThumbnail(imgRecord),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return ExtendedImage.memory(
            data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // 仅限宽 ≤256px 解码：同时限宽限高会把非正方形图片
            // 压成正方形再裁剪，导致缩略图变形
            cacheWidth: 256,
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
    final cs = Theme.of(context).colorScheme;
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
        color = cs.onSurfaceVariant;
    }

    return Center(child: Icon(icon, size: 22, color: color));
  }

  Widget _defaultIcon() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Icon(Icons.image, color: cs.onSurfaceVariant, size: 22),
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
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: ConstrainedText(
              AppLocalizations.of(context)!.appMediaSelectedFiles(items.length),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                      _pendingReadGenerationByKey[key] =
                          (_pendingReadGenerationByKey[key] ?? 0) + 1;
                    });
                  },
                  onTap: isImage ? () => _onPreviewImageTap(entry) : null,
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
  /// The quick editor processes the image in place and pops back with the
  /// edited bytes only after the pipeline finishes.
  /// [entry] is the exact [MapEntry] instance stored in [_selectedItems]
  /// (identity is used to locate the item after editing).
  Future<void> _onPreviewImageTap(MapEntry<String, Uint8List> entry) async {
    final editGeneration = _selectionGeneration;
    final fileName = entry.key;
    final imageBytes = entry.value;
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          ImagePreviewDialog(imageData: imageBytes, fileName: fileName),
    );

    if (shouldEdit != true || !mounted) return;

    final editedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExtendedImageEditorPage(imageBytes: imageBytes, fileName: fileName),
      ),
    );

    if (editedBytes == null || !mounted) return;

    // Save edited bytes to temp cache directory (do NOT overwrite original)
    try {
      final directoryProvider = widget.tempDirectoryProvider;
      final tempDir = directoryProvider == null
          ? await getTemporaryDirectory()
          : await directoryProvider();
      if (!mounted ||
          editGeneration != _selectionGeneration ||
          !_selectedItems.values.any(
            (selected) => identical(selected, entry),
          )) {
        return;
      }
      final tempFileName =
          'edited_${DateTime.now().microsecondsSinceEpoch}_$fileName';
      final tempFile = File('${tempDir.path}/$tempFileName');
      _tempEditFiles.add(tempFile.path);
      final write = _writeTempEditFile(tempFile, editedBytes);
      _pendingTempFileWrites.add(write);
      try {
        await write;
      } finally {
        _pendingTempFileWrites.remove(write);
      }
    } catch (_) {
      // Temp file save is best-effort; keep bytes in memory
    }

    // Update the selected item in-memory with edited bytes
    try {
      final key =
          _selectedItems.entries.firstWhere((e) => e.value == entry).key;
      if (mounted) {
        setState(() {
          _selectedItems[key] = MapEntry(fileName, editedBytes);
        });
      }
    } catch (_) {
      // Item was removed while editor was open — silently ignore
    }
  }

  Future<void> _writeTempEditFile(File file, Uint8List bytes) async {
    try {
      final writer = widget.tempFileWriter;
      if (writer == null) {
        await file.writeAsBytes(bytes);
      } else {
        await writer(file.path, bytes);
      }
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
        _tempEditFiles.remove(file.path);
      } catch (_) {
        // Keep the path tracked so the picker cleanup can retry it.
      }
    }
  }
}
