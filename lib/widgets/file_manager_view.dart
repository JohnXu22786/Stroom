import 'dart:collection';

import 'package:flutter/material.dart';

import '../utils/file_record.dart';
import '../utils/manifest_bridge.dart';
import '../utils/sort_config.dart';
import 'file_manager_config.dart';
import 'file_manager_utils.dart';

export 'file_manager_config.dart';

// ====================================================================
// FileManagerView — reusable file-manager stateful widget
// ====================================================================

class FileManagerView<T extends FileRecord> extends StatefulWidget {
  final List<T> sortedRecords;
  final Set<String> folders;
  final SortConfig sortConfig;
  final FileManagerConfig<T> config;

  // Mutation callbacks
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id, String newName) onRenameFile;
  final Future<void> Function(String id, String targetFolder) onMoveFile;
  final Future<void> Function(String id, String selectedFolder) onCopyFile;
  final Future<void> Function(String id) onDeleteFile;
  final Future<void> Function(List<String> ids) onDeleteFiles;
  final Future<void> Function(List<String> names) onDeleteFolders;
  final Future<void> Function(List<String> ids, String targetFolder)
      onMoveFiles;
  final Future<void> Function(List<String> names, String targetFolder)
      onMoveFolders;
  final Future<void> Function(String id) onExportFile;
  final Future<void> Function(List<String> ids, String targetDirectory)?
      onExportFiles;
  final Future<void> Function(List<String> names, String targetDirectory)?
      onExportFolders;
  final Future<void> Function(String name)? onExportFolder;
  final Future<void> Function(String oldName, String newName) onRenameFolder;
  final Future<void> Function(String name, String targetParent) onMoveFolder;
  final Future<void> Function(String name, String targetParent) onCopyFolder;
  final Future<void> Function(String name) onDeleteFolder;
  final Future<void> Function(String name) onCreateFolder;
  final void Function(SortField) onToggleSort;
  final Future<void> Function()? onImport;

  // Manifest helper statics
  final ManifestBridge manifestBridge;

  /// External signal from the outer PopScope in [HomePage].
  /// When this counter changes and [FileManagerView] is in a subfolder,
  /// it navigates to the parent folder.
  /// This replaces the inner PopScope that previously handled back navigation.
  final int navigateToParentSignal;

  /// Whether this [FileManagerView] is the currently active tab in [TabBarView].
  /// When false, the widget ignores [navigateToParentSignal] changes to prevent
  /// silent navigation in inactive tabs that were left in a subfolder.
  final bool isActiveTab;

  /// External signal for "double-tap current tab → reset to root".
  /// When this value changes, [_FileManagerViewState] resets [_currentFolder]
  /// to an empty string (root), unless it is already at root.
  final int tabResetSignal;

  const FileManagerView({
    super.key,
    required this.sortedRecords,
    required this.folders,
    required this.sortConfig,
    required this.config,
    required this.onRefresh,
    required this.onRenameFile,
    required this.onMoveFile,
    required this.onCopyFile,
    required this.onDeleteFile,
    required this.onDeleteFiles,
    required this.onDeleteFolders,
    required this.onMoveFiles,
    required this.onMoveFolders,
    required this.onExportFile,
    this.onExportFiles,
    this.onExportFolders,
    this.onExportFolder,
    required this.onRenameFolder,
    required this.onMoveFolder,
    required this.onCopyFolder,
    required this.onDeleteFolder,
    required this.onCreateFolder,
    required this.onToggleSort,
    this.onImport,
    required this.manifestBridge,
    this.navigateToParentSignal = 0,
    this.isActiveTab = true,
    this.tabResetSignal = 0,
  });

  @override
  State<FileManagerView<T>> createState() => _FileManagerViewState<T>();
}

class _FileManagerViewState<T extends FileRecord>
    extends State<FileManagerView<T>> {
  final _folderNameController = TextEditingController();
  final _renameController = TextEditingController();
  String? _selectedFileId;

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  String _currentFolder = '';
  bool _showGridView = false;

  /// 缓存缩略图 Widget，避免勾选等操作触发 setState 时重新从磁盘读取
  static const int _maxThumbnailCache = 200;
  final LinkedHashMap<String, Widget> _thumbnailCache = LinkedHashMap();

  @override
  void initState() {
    super.initState();
    _showGridView = widget.config.initialGridView;
    // 同步初始文件夹状态到外部 Provider，确保 filesPageCurrentFolderProvider
    // 在新标签页首次创建时正确地反映当前文件夹
    widget.config.onCurrentFolderChanged?.call(_currentFolder);
  }

  @override
  void didUpdateWidget(covariant FileManagerView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 数据记录引用变化时清空缩略图缓存
    if (oldWidget.sortedRecords != widget.sortedRecords) {
      _thumbnailCache.clear();
    }
    // 检测外部导航到父文件夹的信号（仅活动标签页响应）
    if (widget.isActiveTab &&
        widget.navigateToParentSignal != oldWidget.navigateToParentSignal &&
        _currentFolder.isNotEmpty) {
      // 计算信号差值，处理快速连续点击导致的信号合并
      final signalDiff =
          widget.navigateToParentSignal - oldWidget.navigateToParentSignal;
      for (int i = 0; i < signalDiff && _currentFolder.isNotEmpty; i++) {
        _setCurrentFolder(
          widget.manifestBridge.getParentFolderPath(_currentFolder),
        );
      }
    }
    // 检测同标签页双击重置信号 — _currentFolder非空时重置到根目录
    if (widget.tabResetSignal != oldWidget.tabResetSignal &&
        _currentFolder.isNotEmpty) {
      _setCurrentFolder('');
    }
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  /// 通知缩略图缓存失效（在数据刷新后调用）
  void _invalidateThumbnailCache() {
    _thumbnailCache.clear();
  }

  /// 向缩略图缓存中添加条目，达到 [_maxThumbnailCache] 上限时淘汰最旧的条目。
  Widget _putThumbnailCache(String key, Widget Function() builder) {
    if (_thumbnailCache.containsKey(key)) {
      return _thumbnailCache[key]!;
    }
    if (_thumbnailCache.length >= _maxThumbnailCache) {
      _thumbnailCache.remove(_thumbnailCache.keys.first);
    }
    return _thumbnailCache.putIfAbsent(key, builder);
  }

  // ====================================================================
  // Selection mode
  // ====================================================================

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

  void _toggleFolderSelection(String folderPath) {
    setState(() {
      if (_selectedIds.contains(folderPath)) {
        _selectedIds.remove(folderPath);
      } else {
        _selectedIds.add(folderPath);
      }
    });
  }

  /// Subfolder paths visible in the current folder
  List<String> _currentFolderSubfolders() {
    return _getDirectSubFolders(_currentFolder, widget.folders);
  }

  /// All visible items in the current folder (files + subfolder paths combined)
  Set<String> _allVisibleItemIds() {
    final isInFolder = _currentFolder.isNotEmpty;
    final fileIds = widget.sortedRecords
        .where(
          (r) => isInFolder ? r.folder == _currentFolder : r.folder.isEmpty,
        )
        .map((r) => r.id)
        .toSet();
    final folderPaths = _currentFolderSubfolders().toSet();
    return {...fileIds, ...folderPaths};
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_allVisibleItemIds());
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _setCurrentFolder(String folder) {
    setState(() => _currentFolder = folder);
    widget.config.onCurrentFolderChanged?.call(folder);
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<T>>{};
    for (final r in widget.sortedRecords) {
      final folder = r.folder.isEmpty ? '' : r.folder;
      grouped.putIfAbsent(folder, () => []).add(r);
    }

    final showGrid =
        widget.config.fileThumbnailBuilder != null && _showGridView;

    return Scaffold(
      key: const Key('fm_scaffold'),
      appBar: _buildAppBar(grouped),
      body: Column(
        children: [
          if (widget.config.topActionBar != null) widget.config.topActionBar!,
          Expanded(
            child: showGrid
                ? _buildGridView(grouped)
                : _buildFileListView(grouped),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSelectionActionButton(
                        key: const Key('fm_selection_copy_btn'),
                        onPressed: _copySelected,
                        icon: const Icon(Icons.copy, size: 20),
                        label: '复制',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSelectionActionButton(
                        key: const Key('fm_selection_move_btn'),
                        onPressed: _moveSelected,
                        icon: const Icon(
                          Icons.drive_file_move_outline,
                          size: 20,
                        ),
                        label: '移动',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSelectionActionButton(
                        key: const Key('fm_selection_export_btn'),
                        onPressed: _exportSelected,
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 20,
                        ),
                        label: '导出',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSelectionActionButton(
                        key: const Key('fm_selection_delete_btn'),
                        onPressed: _deleteSelected,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        label: '删除',
                        labelStyle: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  /// Build a selection-mode action button that hides the label on narrow
  /// screens (<400dp) to prevent text overflow / vertical wrapping.
  Widget _buildSelectionActionButton({
    required Key key,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    TextStyle? labelStyle,
  }) {
    final showLabel = MediaQuery.of(context).size.width >= 400;
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: icon,
      label: showLabel
          ? Text(label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1)
          : const SizedBox.shrink(),
    );
  }

  PreferredSizeWidget _buildAppBar(Map<String, List<T>> grouped) {
    return AppBar(
      primary: false,
      title: Text(
        _selectionMode
            ? '已选择 ${_selectedIds.length} 项'
            : _currentFolder.isNotEmpty
                ? _currentFolder
                : widget.config.title,
      ),
      centerTitle: true,
      leading: _selectionMode
          ? IconButton(
              key: const Key('fm_close_selection_btn'),
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : (_currentFolder.isNotEmpty
              ? IconButton(
                  key: const Key('fm_back_btn'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _setCurrentFolder(
                      widget.manifestBridge.getParentFolderPath(
                        _currentFolder,
                      ),
                    );
                  },
                )
              : null),
      actions: [
        if (_selectionMode) ...[
          IconButton(
            key: const Key('fm_select_all_btn'),
            icon: const Icon(Icons.select_all),
            tooltip: '全选',
            onPressed: () {
              final allVisible = _allVisibleItemIds();
              if (_selectedIds.length >= allVisible.length &&
                  allVisible.isNotEmpty) {
                _deselectAll();
              } else {
                _selectAll();
              }
            },
          ),
        ] else ...[
          // Extra app bar actions (e.g. task list button)
          if (widget.config.extraAppBarActions != null)
            ...widget.config.extraAppBarActions!(),
          // Sort button
          PopupMenuButton<SortField>(
            key: const Key('fm_sort_btn'),
            icon: const Icon(Icons.sort),
            tooltip: '排序（${widget.sortConfig.label}）',
            onSelected: widget.onToggleSort,
            itemBuilder: (_) => [
              _buildSortMenuItem(SortField.createdAt, '按时间'),
              _buildSortMenuItem(SortField.name, '按文件名'),
              _buildSortMenuItem(SortField.size, '按大小'),
            ],
          ),
          // Thumbnail toggle
          if (widget.config.showThumbnailToggle)
            IconButton(
              key: const Key('fm_grid_toggle_btn'),
              icon: Icon(_showGridView ? Icons.view_list : Icons.grid_view),
              tooltip: _showGridView ? '列表视图' : '缩略图视图',
              onPressed: () {
                final newValue = !_showGridView;
                setState(() => _showGridView = newValue);
                widget.config.onGridViewChanged?.call(newValue);
              },
            ),
          // Create folder
          IconButton(
            key: const Key('fm_create_folder_btn'),
            icon: const Icon(Icons.create_new_folder),
            tooltip: '创建文件夹',
            onPressed: _createFolder,
          ),
          // Refresh
          IconButton(
            key: const Key('fm_refresh_btn'),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: _refreshFileList,
          ),
        ],
      ],
    );
  }

  PopupMenuEntry<SortField> _buildSortMenuItem(SortField field, String label) {
    final isSelected = widget.sortConfig.field == field;
    return CheckedPopupMenuItem(
      value: field,
      checked: isSelected,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (isSelected)
            Icon(
              widget.sortConfig.order == SortOrder.descending
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 16,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  // ====================================================================
  // List view
  // ====================================================================

  Widget _buildFileListView(Map<String, List<T>> grouped) {
    final isInFolder = _currentFolder.isNotEmpty;

    // 使用 widget.folders（来自 provider 的全量合并集）而非 getChildFolderPaths（只读 _folderCache）
    final subFolders = _getDirectSubFolders(_currentFolder, widget.folders);
    subFolders.sort((a, b) {
      final nameA = widget.manifestBridge.getFolderBaseName(a).toLowerCase();
      final nameB = widget.manifestBridge.getFolderBaseName(b).toLowerCase();
      return widget.sortConfig.order == SortOrder.descending
          ? nameB.compareTo(nameA)
          : nameA.compareTo(nameB);
    });

    final currentFiles =
        isInFolder ? (grouped[_currentFolder] ?? []) : (grouped[''] ?? []);

    final hasContent = subFolders.isNotEmpty || currentFiles.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInFolder ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isInFolder ? '此文件夹为空' : '暂无文件',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final allItems = <dynamic>[
      if (isInFolder) 'back',
      for (final f in subFolders) f,
      ...currentFiles,
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is String && item == 'back') {
          return _buildBackItem();
        } else if (item is String) {
          // folder name
          return _buildFolderItem(item, grouped[item]?.length ?? 0);
        } else {
          // file record
          return _buildFileItem(item as T);
        }
      },
    );
  }

  Widget _buildBackItem() {
    final parentFolder = widget.manifestBridge.getParentFolderPath(
      _currentFolder,
    );
    return Card(
      key: const Key('fm_back_item'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => _setCurrentFolder(parentFolder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                parentFolder.isEmpty
                    ? '返回根目录'
                    : '返回: ${widget.manifestBridge.getFolderBaseName(parentFolder)}',
                style: TextStyle(fontSize: 15, color: Colors.blue[700]),
              ),
              const Spacer(),
              Text(
                widget.manifestBridge.getFolderBaseName(_currentFolder),
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // Grid view
  // ====================================================================

  Widget _buildGridView(Map<String, List<T>> grouped) {
    final isInFolder = _currentFolder.isNotEmpty;

    // 使用 widget.folders（来自 provider 的全量合并集）
    final subFolders = _getDirectSubFolders(_currentFolder, widget.folders);
    subFolders.sort((a, b) {
      final nameA = widget.manifestBridge.getFolderBaseName(a).toLowerCase();
      final nameB = widget.manifestBridge.getFolderBaseName(b).toLowerCase();
      return widget.sortConfig.order == SortOrder.descending
          ? nameB.compareTo(nameA)
          : nameA.compareTo(nameB);
    });

    final currentFiles =
        isInFolder ? (grouped[_currentFolder] ?? []) : (grouped[''] ?? []);

    final hasContent = subFolders.isNotEmpty || currentFiles.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInFolder ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isInFolder ? '此文件夹为空' : '暂无文件',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final allItems = <dynamic>[
      if (isInFolder) 'back',
      for (final f in subFolders) f,
      ...currentFiles,
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (item is String && item == 'back') {
          return _buildGridBackItem();
        } else if (item is String) {
          return _buildGridFolderItem(item, grouped[item]?.length ?? 0);
        } else {
          return _buildGridFileItem(item as T);
        }
      },
    );
  }

  Widget _buildGridBackItem() {
    final parentFolder = widget.manifestBridge.getParentFolderPath(
      _currentFolder,
    );
    return GestureDetector(
      key: const Key('fm_grid_back_item'),
      onTap: () => _setCurrentFolder(parentFolder),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_back, size: 32, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              parentFolder.isEmpty ? '根目录' : '..',
              style: TextStyle(fontSize: 11, color: Colors.blue[700]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridFolderItem(String folderName, int fileCount) {
    final isSelected = _selectedIds.contains(folderName);
    return GestureDetector(
      key: Key('fm_grid_folder_$folderName'),
      onTap: () {
        if (_selectionMode) {
          _toggleFolderSelection(folderName);
        } else {
          _setCurrentFolder(folderName);
        }
      },
      onLongPress: () {
        if (!_selectionMode) {
          _enterSelectionMode(folderName);
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(
                  child: Icon(
                    Icons.folder_outlined,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.manifestBridge.getFolderBaseName(folderName),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileCount > 0)
                  Center(
                    child: Text(
                      '$fileCount',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectionMode)
            Positioned(
              top: 2,
              right: 2,
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleFolderSelection(folderName),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridFileItem(T file) {
    final isSelected = _selectedIds.contains(file.id);
    final hasThumbnailBuilder = widget.config.fileThumbnailBuilder != null;
    return GestureDetector(
      key: Key('fm_grid_file_${file.id}'),
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(file.id);
        } else {
          widget.config.onFileTap(file);
        }
      },
      onLongPress: () {
        if (!_selectionMode) {
          _enterSelectionMode(file.id);
          widget.config.onLongPress?.call(file);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            // Thumbnail area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
                child: hasThumbnailBuilder
                    ? _putThumbnailCache(
                        file.id,
                        () => widget.config.fileThumbnailBuilder!.call(file),
                      )
                    : widget.config.fileIconBuilder(file),
              ),
            ),
            // Name + checkbox
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${file.name}.${file.format}',
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectionMode)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(file.id),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Folder item
  // ====================================================================

  Widget _buildFolderItem(String folderName, int fileCount) {
    final isSelected = _selectedIds.contains(folderName);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Card(
        key: Key('fm_folder_$folderName'),
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            if (_selectionMode) {
              _toggleFolderSelection(folderName);
            } else {
              _setCurrentFolder(folderName);
            }
          },
          onLongPress: () {
            if (!_selectionMode) {
              _enterSelectionMode(folderName);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                if (_selectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleFolderSelection(folderName),
                  ),
                // Folder icon
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
                // Folder info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.manifestBridge.getFolderBaseName(folderName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
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
                // Popup menu
                if (!_selectionMode)
                  PopupMenuButton<String>(
                    key: Key('fm_folder_popup_$folderName'),
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'multiSelect':
                          _toggleFolderSelection(folderName);
                          if (!_selectionMode) {
                            setState(() => _selectionMode = true);
                          }
                        case 'open':
                          _setCurrentFolder(folderName);
                        case 'rename':
                          _renameFolder(folderName);
                        case 'move':
                          _moveFolder(folderName);
                        case 'copy':
                          _copyFolder(folderName);
                        case 'delete':
                          _deleteFolder(folderName);
                        case 'export':
                          _exportFolder(folderName);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'multiSelect',
                        child: ListTile(
                          key: Key('fm_folder_menu_multi_select'),
                          leading: Icon(Icons.checklist, size: 20),
                          title: Text('多选'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'open',
                        child: ListTile(
                          key: Key('fm_folder_menu_open'),
                          leading: Icon(Icons.folder_open, size: 20),
                          title: Text('打开'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          key: Key('fm_folder_menu_rename'),
                          leading: Icon(Icons.edit, size: 20),
                          title: Text('重命名'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'move',
                        child: ListTile(
                          key: Key('fm_folder_menu_move'),
                          leading: Icon(Icons.drive_file_move, size: 20),
                          title: Text('移动'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          key: Key('fm_folder_menu_copy'),
                          leading: Icon(Icons.copy, size: 20),
                          title: Text('复制'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          key: Key('fm_folder_menu_export'),
                          leading: Icon(Icons.file_download_outlined, size: 20),
                          title: Text('导出'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          key: Key('fm_folder_menu_delete'),
                          leading: Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          title: Text(
                            '删除',
                            style: TextStyle(color: Colors.red),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _folderDetailText(String folderName, int fileCount) {
    // 使用 widget.folders（全量合并集）而非 getChildFolderPaths（只读 _folderCache）
    final subFolderCount = _getDirectSubFolders(
      folderName,
      widget.folders,
    ).length;
    if (subFolderCount > 0 && fileCount > 0) {
      return '$fileCount 个文件, $subFolderCount 个子文件夹';
    } else if (subFolderCount > 0) {
      return '$subFolderCount 个子文件夹';
    } else if (fileCount > 0) {
      return '$fileCount 个文件';
    } else {
      return '空文件夹';
    }
  }

  // ====================================================================
  // File item
  // ====================================================================

  Widget _buildFileItem(T file) {
    final isSelected = _selectedIds.contains(file.id);
    final fileSizeStr = formatFileSize(file.size);
    final dateStr = formatDate(file.createdAt);
    final hasThumbnailBuilder = widget.config.fileThumbnailBuilder != null;

    return Card(
      key: Key('fm_file_${file.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(file.id);
          } else {
            widget.config.onFileTap(file);
          }
        },
        onLongPress: () {
          if (!_selectionMode) {
            _enterSelectionMode(file.id);
            widget.config.onLongPress?.call(file);
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
              // File icon / thumbnail (cached)
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasThumbnailBuilder
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: hasThumbnailBuilder ? Clip.antiAlias : Clip.none,
                child: hasThumbnailBuilder
                    ? _putThumbnailCache(
                        file.id,
                        () => widget.config.fileThumbnailBuilder!.call(file),
                      )
                    : widget.config.fileIconBuilder(file),
              ),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${file.name}.${file.format}',
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
                        // Only show folder path when different from current browsing folder
                        if (file.folder.isNotEmpty &&
                            file.folder != _currentFolder) ...[
                          Icon(Icons.folder, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            file.folder,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey[400]!,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey[400]!,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fileSizeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Popup menu
              if (!_selectionMode)
                PopupMenuButton<String>(
                  key: Key('fm_file_popup_${file.id}'),
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) => _onFilePopupAction(value, file),
                  itemBuilder: (_) => _buildFilePopupMenu(file),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildFilePopupMenu(T file) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'multiSelect',
        child: ListTile(
          key: Key('fm_file_menu_multi_select'),
          leading: Icon(Icons.checklist, size: 20),
          title: Text('多选'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'preview',
        child: ListTile(
          key: Key('fm_file_menu_preview'),
          leading: Icon(Icons.visibility, size: 20),
          title: Text('预览'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'rename',
        child: ListTile(
          key: Key('fm_file_menu_rename'),
          leading: Icon(Icons.edit, size: 20),
          title: Text('重命名'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'move',
        child: ListTile(
          key: Key('fm_file_menu_move'),
          leading: Icon(Icons.drive_file_move, size: 20),
          title: Text('移动'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'copy',
        child: ListTile(
          key: Key('fm_file_menu_copy'),
          leading: Icon(Icons.copy, size: 20),
          title: Text('复制'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          key: Key('fm_file_menu_delete'),
          leading: Icon(Icons.delete, size: 20, color: Colors.red),
          title: Text('删除', style: TextStyle(color: Colors.red)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];

    // Insert extra items from config before delete
    final extraItems = widget.config.extraPopupMenuItems(file);
    if (extraItems.isNotEmpty) {
      items.insertAll(items.length - 1, extraItems);
    }

    return items;
  }

  void _onFilePopupAction(String value, T file) {
    switch (value) {
      case 'multiSelect':
        _enterSelectionMode(file.id);
      case 'preview':
        widget.config.onFileTap(file);
      case 'rename':
        _renameFile(file.id, file.name);
      case 'move':
        _moveFile(file.id);
      case 'copy':
        _copyFile(file.id);
      case 'export':
        widget.onExportFile(file.id);
      case 'delete':
        _deleteFile(file.id);
      default:
        widget.config.onExtraMenuAction?.call(file, value);
        break;
    }
  }

  // ====================================================================
  // File operations
  // ====================================================================

  Future<void> _renameFile(String fileId, String currentName) async {
    _renameController.text = currentName;
    _selectedFileId = fileId;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_rename_file_dialog'),
        title: const Text('重命名文件'),
        content: TextField(
          key: const Key('fm_rename_file_input'),
          controller: _renameController,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('fm_rename_cancel_btn'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: const Key('fm_rename_confirm_btn'),
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
      final newName = result.trim();
      // Conflict check
      final conflict = widget.sortedRecords.any(
        (r) =>
            r.name == newName &&
            r.folder == _currentFolder &&
            r.id != _selectedFileId,
      );
      if (conflict) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('文件 "$newName" 已存在'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _renameController.clear();
        _selectedFileId = null;
        return;
      }
      await widget.onRenameFile(_selectedFileId!, newName);
      _renameController.clear();
      _selectedFileId = null;
    }
  }

  Future<void> _moveFile(String fileId) async {
    final selectedFolder = await _showFolderPickerDialog(
      widget.folders,
      title: '选择目标文件夹',
    );
    if (selectedFolder != null) {
      if (!mounted) return;
      await widget.onMoveFile(fileId, selectedFolder);
    }
    if (mounted) setState(() {});
  }

  Future<void> _copyFile(String fileId) async {
    final selectedFolder = await _showFolderPickerDialog(
      widget.folders,
      title: '选择复制到的目标文件夹',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    await widget.onCopyFile(fileId, selectedFolder);
    if (mounted) setState(() {});
  }

  Future<void> _deleteFile(String fileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_delete_file_dialog'),
        title: const Text('确认删除'),
        content: const Text('确定要删除此文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            key: const Key('fm_delete_cancel_btn'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('fm_delete_confirm_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await widget.onDeleteFile(fileId);
      _exitSelectionMode();
    }
  }

  List<String> _fileIdsExcludingFolderFiles(
    List<String> fileIds,
    List<String> folderNames,
  ) {
    return fileIds.where((id) {
      final matches = widget.sortedRecords.where((r) => r.id == id);
      if (matches.isEmpty) return true;
      final file = matches.first;
      return !folderNames.any(
        (fn) => file.folder == fn || file.folder.startsWith('$fn/'),
      );
    }).toList();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_delete_selected_dialog'),
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            key: const Key('fm_batch_delete_cancel_btn'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('fm_batch_delete_confirm_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final fileIds = <String>[];
      final folderNames = <String>[];
      for (final id in _selectedIds) {
        if (widget.folders.contains(id)) {
          folderNames.add(id);
        } else {
          fileIds.add(id);
        }
      }
      final adjustedFileIds = _fileIdsExcludingFolderFiles(
        fileIds,
        folderNames,
      );
      if (adjustedFileIds.isNotEmpty) {
        await widget.onDeleteFiles(adjustedFileIds);
      }
      for (final name in folderNames) {
        await widget.onDeleteFolder(name);
      }
      _exitSelectionMode();
    }
  }

  Future<void> _exportSelected() async {
    if (_selectedIds.isEmpty) return;

    if (!mounted) return;

    // Separate files and folders
    final fileIds = <String>[];
    final folderNames = <String>[];
    for (final id in _selectedIds) {
      if (widget.folders.contains(id)) {
        folderNames.add(id);
      } else {
        fileIds.add(id);
      }
    }

    final adjustedFileIds = _fileIdsExcludingFolderFiles(fileIds, folderNames);

    // Export files
    if (adjustedFileIds.isNotEmpty && widget.onExportFiles != null) {
      await widget.onExportFiles!(adjustedFileIds, '');
    }

    // Export folders
    for (final name in folderNames) {
      if (widget.onExportFolder != null) {
        await widget.onExportFolder!(name);
      }
    }

    _exitSelectionMode();
    if (mounted) setState(() {});
  }

  Future<void> _exportFolder(String folderName) async {
    if (widget.onExportFolder != null) {
      await widget.onExportFolder!(folderName);
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty) return;

    final selectedFolder = await _showFolderPickerDialog(
      widget.folders,
      title: '选择目标文件夹',
    );

    if (selectedFolder != null) {
      if (!mounted) return;
      final fileIds = <String>[];
      final folderNames = <String>[];
      for (final id in _selectedIds) {
        if (widget.folders.contains(id)) {
          folderNames.add(id);
        } else {
          fileIds.add(id);
        }
      }
      final adjustedFileIds = _fileIdsExcludingFolderFiles(
        fileIds,
        folderNames,
      );
      if (adjustedFileIds.isNotEmpty) {
        await widget.onMoveFiles(adjustedFileIds, selectedFolder);
      }
      await Future.wait(
        folderNames.map((name) => widget.onMoveFolder(name, selectedFolder)),
      );
      _exitSelectionMode();
    }
    if (mounted) setState(() {});
  }

  Future<void> _copySelected() async {
    if (_selectedIds.isEmpty) return;

    final selectedFolder = await _showFolderPickerDialog(
      widget.folders,
      title: '选择目标文件夹',
    );

    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    final fileIds = <String>[];
    final folderNames = <String>[];
    for (final id in _selectedIds) {
      if (widget.folders.contains(id)) {
        folderNames.add(id);
      } else {
        fileIds.add(id);
      }
    }
    final adjustedFileIds = _fileIdsExcludingFolderFiles(fileIds, folderNames);
    await Future.wait(
      adjustedFileIds.map((id) => widget.onCopyFile(id, selectedFolder)),
    );
    await Future.wait(
      folderNames.map((name) => widget.onCopyFolder(name, selectedFolder)),
    );
    _exitSelectionMode();
    if (mounted) setState(() {});
  }

  // ====================================================================
  // Folder operations
  // ====================================================================

  Future<void> _createFolder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_create_folder_dialog'),
        title: const Text('创建文件夹'),
        content: TextField(
          key: const Key('fm_create_folder_input'),
          controller: _folderNameController,
          decoration: const InputDecoration(
            hintText: '输入文件夹名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('fm_create_folder_cancel_btn'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: const Key('fm_create_folder_confirm_btn'),
            onPressed: () {
              final name = _folderNameController.text.trim();
              if (name.isNotEmpty &&
                  widget.manifestBridge.validateFolderName(name) == null) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final error = widget.manifestBridge.validateFolderName(result);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      _folderNameController.clear();
      // Prepend the current folder path to create subfolder hierarchy
      final fullPath =
          _currentFolder.isEmpty ? result : '$_currentFolder/$result';
      await widget.onCreateFolder(fullPath);
      // If we're at root, navigate into the newly created folder
      if (_currentFolder.isEmpty) {
        _setCurrentFolder(result);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件夹 "$result" 创建成功'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _renameFolder(String folderName) async {
    _renameController.text = folderName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_rename_folder_dialog'),
        title: const Text('重命名文件夹'),
        content: TextField(
          key: const Key('fm_rename_folder_input'),
          controller: _renameController,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            key: const Key('fm_rename_folder_cancel_btn'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: const Key('fm_rename_folder_confirm_btn'),
            onPressed: () {
              final name = _renameController.text.trim();
              if (name.isNotEmpty &&
                  widget.manifestBridge.validateFolderName(name) == null) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
    _renameController.clear();

    if (result != null && result.isNotEmpty && result != folderName) {
      final error = widget.manifestBridge.validateFolderName(result);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await widget.onRenameFolder(folderName, result);
      if (_currentFolder == folderName ||
          _currentFolder.startsWith('$folderName/')) {
        final parentPath = widget.manifestBridge.getParentFolderPath(
          folderName,
        );
        final newFullPath = parentPath.isEmpty ? result : '$parentPath/$result';
        if (_currentFolder == folderName) {
          _setCurrentFolder(newFullPath);
        } else {
          final suffix = _currentFolder.substring(folderName.length);
          _setCurrentFolder('$newFullPath$suffix');
        }
      }
    }
  }

  Future<void> _moveFolder(String folderName) async {
    final descendants = widget.manifestBridge.getAllDescendantFolderPaths(
      folderName,
      widget.folders,
    );
    final excluded = {folderName, ...descendants};
    final targetFolders =
        widget.folders.where((f) => !excluded.contains(f)).toSet();

    final selectedFolder = await _showFolderPickerDialog(
      targetFolders,
      title: '移动文件夹到…',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    await widget.onMoveFolder(folderName, selectedFolder);
    if (_currentFolder == folderName) {
      _setCurrentFolder(widget.manifestBridge.getParentFolderPath(folderName));
    }
  }

  Future<void> _copyFolder(String folderName) async {
    final descendants = widget.manifestBridge.getAllDescendantFolderPaths(
      folderName,
      widget.folders,
    );
    final excluded = {folderName, ...descendants};
    final targetFolders =
        widget.folders.where((f) => !excluded.contains(f)).toSet();

    final selectedFolder = await _showFolderPickerDialog(
      targetFolders,
      title: '复制文件夹到…',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    await widget.onCopyFolder(folderName, selectedFolder);
  }

  Future<void> _deleteFolder(String folderName) async {
    final directCount =
        widget.sortedRecords.where((r) => r.folder == folderName).length;
    final descendants = widget.manifestBridge.getAllDescendantFolderPaths(
      folderName,
      widget.folders,
    );
    int subFileCount = 0;
    for (final desc in descendants) {
      subFileCount +=
          widget.sortedRecords.where((r) => r.folder == desc).length;
    }
    final fileCount = directCount + subFileCount;
    final message = fileCount > 0
        ? '确定要删除文件夹 "$folderName" 吗？其中的 $fileCount 个文件也将被删除。'
        : '确定要删除空文件夹 "$folderName" 吗？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_delete_folder_dialog'),
        title: const Text('确认删除文件夹'),
        content: Text(message),
        actions: [
          TextButton(
            key: const Key('fm_delete_folder_cancel_btn'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('fm_delete_folder_confirm_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await widget.onDeleteFolder(folderName);
      if (_currentFolder == folderName) {
        _setCurrentFolder(
          widget.manifestBridge.getParentFolderPath(folderName),
        );
      }
    }
  }

  Future<void> _refreshFileList() async {
    await widget.onRefresh();
    _invalidateThumbnailCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件列表已刷新'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ====================================================================
  // Folder picker dialog (tree navigation + inline create)
  // ====================================================================

  Future<String?> _showFolderPickerDialog(
    Set<String> folders, {
    String title = '选择目标文件夹',
  }) async {
    final nameController = TextEditingController();
    final focusNode = FocusNode();
    var isCreating = false;
    var pickerCurrentPath = '';
    var currentFolders = Set<String>.from(folders);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Direct subfolders under pickerCurrentPath
          final subFolders = _getDirectSubFolders(
            pickerCurrentPath,
            currentFolders,
          );

          return AlertDialog(
            key: const Key('fm_folder_picker_dialog'),
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Path bar + back button
                  _buildPickerPathBar(pickerCurrentPath, () {
                    setDialogState(() {
                      pickerCurrentPath = widget.manifestBridge
                          .getParentFolderPath(pickerCurrentPath);
                    });
                  }),
                  const Divider(height: 1),
                  // Folder list
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
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
                              child: Text(
                                '此文件夹为空',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ...subFolders.map(
                          (f) => ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(
                              widget.manifestBridge.getFolderBaseName(f),
                            ),
                            dense: true,
                            onTap: () {
                              setDialogState(() {
                                pickerCurrentPath = f;
                              });
                            },
                          ),
                        ),
                        // Inline create folder
                        if (isCreating) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
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
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    onSubmitted: (value) async {
                                      final name = value.trim();
                                      if (name.isEmpty) return;
                                      final err = widget.manifestBridge
                                          .validateFolderName(name);
                                      if (err != null) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(err),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      final newPath = pickerCurrentPath.isEmpty
                                          ? name
                                          : '$pickerCurrentPath/$name';
                                      await widget.onCreateFolder(newPath);
                                      if (ctx.mounted) {
                                        setDialogState(() {
                                          // Manually add the new path instead of re-reading widget.folders
                                          // because widget.folders is the frozen initial set.
                                          currentFolders = {
                                            ...currentFolders,
                                            newPath,
                                          };
                                          isCreating = false;
                                          nameController.clear();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  key: const Key(
                                    'fm_picker_create_confirm_btn',
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                  ),
                                  tooltip: '确认创建',
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) return;
                                    final err = widget.manifestBridge
                                        .validateFolderName(name);
                                    if (err != null) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(err),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    final newPath = pickerCurrentPath.isEmpty
                                        ? name
                                        : '$pickerCurrentPath/$name';
                                    await widget.onCreateFolder(newPath);
                                    if (ctx.mounted) {
                                      setDialogState(() {
                                        // Manually add the new path instead of re-reading widget.folders
                                        // because widget.folders is the frozen initial set.
                                        currentFolders = {
                                          ...currentFolders,
                                          newPath,
                                        };
                                        isCreating = false;
                                        nameController.clear();
                                      });
                                    }
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
                      key: const Key('fm_add_folder_btn'),
                      onPressed: () {
                        setDialogState(() => isCreating = true);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => focusNode.requestFocus(),
                        );
                      },
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 18,
                      ),
                      label: const Text('新建文件夹'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: const Key('fm_picker_cancel_btn'),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        key: const Key('fm_select_folder_btn'),
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

  /// Compute direct subfolders from a set of all folder paths
  List<String> _getDirectSubFolders(String parentPath, Set<String> allFolders) {
    final prefix = parentPath.isEmpty ? '' : '$parentPath/';
    return allFolders.where((f) {
      if (f == parentPath) return false;
      if (parentPath.isEmpty) return !f.contains('/');
      if (!f.startsWith(prefix)) return false;
      final suffix = f.substring(prefix.length);
      return !suffix.contains('/');
    }).toList();
  }

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
}
