import 'dart:collection';

import 'package:flutter/material.dart';

import '../utils/batch_rename.dart';
import '../utils/file_record.dart';
import '../utils/manifest_bridge.dart';
import '../utils/sort_config.dart';
import 'batch_rename_dialog.dart';
import 'file_manager_config.dart';
import 'file_manager_utils.dart';
import 'folder_picker_dialog.dart';

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

  /// 重命名时同时修改文件格式（文本文件 txt/md/mmd 下拉框切换）。
  /// 仅在重命名对话框显示了格式下拉框时被调用；为 null 时格式变更
  /// 会被忽略（回退到 [onRenameFile] 的纯改名路径）。
  final Future<void> Function(String id, String newName, String format)?
      onRenameFileWithFormat;
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

  /// 批量导出文件/文件夹。返回用户最终使用的导出目录
  /// （用户取消目录选择或导出失败时返回 null；Web 端返回 ''）。
  /// 返回非 null 的目录会被传递给后续导出，避免混合选择时弹出两次目录选择。
  final Future<String?> Function(List<String> ids, String targetDirectory)?
      onExportFiles;
  final Future<String?> Function(List<String> names, String targetDirectory)?
      onExportFolders;

  /// 单个文件夹导出。返回用户最终使用的导出目录
  /// （用户取消目录选择或导出失败时返回 null；Web 端返回 ''）。
  final Future<String?> Function(String name)? onExportFolder;
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
    this.onRenameFileWithFormat,
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

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  String _currentFolder = '';
  bool _showGridView = false;

  /// 缓存缩略图 Widget，避免勾选等操作触发 setState 时重新从磁盘读取
  static const int _maxThumbnailCache = 200;
  final LinkedHashMap<String, Widget> _thumbnailCache = LinkedHashMap();

  /// 列表/网格中的「返回上级」哨兵项。
  /// 用对象而非字符串，避免与名为 "back" 的真实文件夹冲突
  /// （字符串哨兵会让名为 back 的文件夹被渲染成返回卡片而无法访问）。
  static const _backMarker = Object();

  /// 缩略图缓存的记录集合指纹（排序后的 id 列表）。
  /// 记录是不可变的：内容变化总是产生新 id 的新记录，
  /// 因此 id 集合不变时缓存可安全复用，避免父级每次重建
  /// （如切换排序/视图模式）时误清缓存导致反复读盘。
  /// 注意：缩略图生成失败被缓存后不会自动重试，可通过刷新按钮清缓存。
  String _cacheFingerprint = '';

  String _recordsFingerprint(List<T> records) {
    final ids = records.map((r) => r.id).toList()..sort();
    return ids.join('\u0001');
  }

  @override
  void initState() {
    super.initState();
    _showGridView = widget.config.initialGridView;
    _cacheFingerprint = _recordsFingerprint(widget.sortedRecords);
    // 同步初始文件夹状态到外部 Provider，确保 filesPageCurrentFolderProvider
    // 在新标签页首次创建时正确地反映当前文件夹
    widget.config.onCurrentFolderChanged?.call(_currentFolder);
  }

  @override
  void didUpdateWidget(covariant FileManagerView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 标签页从不活动变为活动时，把当前文件夹同步到外部 Provider。
    // 否则 HomePage 的返回逻辑可能读到其他标签页留下的过期路径，
    // 导致系统返回键被消费却没有任何导航（用户被困在文件页）。
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      widget.config.onCurrentFolderChanged?.call(_currentFolder);
    }
    // 数据记录引用变化时清空缩略图缓存（按 id 集合指纹判断，
    // 记录内容不变则不清理）
    final fingerprint = _recordsFingerprint(widget.sortedRecords);
    if (fingerprint != _cacheFingerprint) {
      _thumbnailCache.clear();
      _cacheFingerprint = fingerprint;
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
    if (!mounted) return;
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
                        key: const Key('fm_selection_rename_btn'),
                        onPressed: _renameSelected,
                        icon: const Icon(
                          Icons.drive_file_rename_outline,
                          size: 20,
                        ),
                        label: '重命名',
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
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  /// 选择模式操作按钮：仅图标 + 长按提示，不显示文字标签。
  /// 图标按钮在窄屏（手机）与宽屏（桌面）上都保持一致的紧凑布局。
  Widget _buildSelectionActionButton({
    required Key key,
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return Tooltip(
      message: label,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          minimumSize: const Size(0, 40),
        ),
        child: icon,
      ),
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
              // 以「当前可见项是否全部选中」为切换依据：
              // 选择模式支持跨文件夹导航，用总数比较会被其他文件夹
              // 的旧选择干扰，导致取消全选时误清全部选择
              final allVisibleSelected = allVisible.isNotEmpty &&
                  allVisible.every(_selectedIds.contains);
              if (allVisibleSelected) {
                setState(() => _selectedIds.removeAll(allVisible));
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
      if (isInFolder) _backMarker,
      for (final f in subFolders) f,
      ...currentFiles,
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        if (identical(item, _backMarker)) {
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
      if (isInFolder) _backMarker,
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
        if (identical(item, _backMarker)) {
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
          // 弹出菜单（与列表视图一致），选择模式下隐藏
          if (!_selectionMode)
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                key: Key('fm_grid_folder_popup_$folderName'),
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) => _onFolderPopupAction(
                  value,
                  folderName,
                ),
                itemBuilder: (_) => _buildFolderPopupMenu(),
                padding: EdgeInsets.zero,
                iconSize: 18,
                // 网格单元较小（约 114-130dp），收窄点击区域，
                // 避免 48dp 的默认按钮遮挡单元格内容
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      child: Stack(
        children: [
          Container(
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
                            () => widget.config.fileThumbnailBuilder!.call(
                              file,
                            ),
                          )
                        : widget.config.fileIconBuilder(file),
                  ),
                ),
                // Name + checkbox
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(7),
                    ),
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 弹出菜单（与列表视图一致），选择模式下隐藏
          if (!_selectionMode)
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                key: Key('fm_grid_file_popup_${file.id}'),
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) => _onFilePopupAction(value, file),
                itemBuilder: (_) => _buildFilePopupMenu(file),
                padding: EdgeInsets.zero,
                iconSize: 18,
                // 网格单元较小（约 114-130dp），收窄点击区域，
                // 避免 48dp 的默认按钮遮挡单元格内容
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
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
                    onSelected: (value) => _onFolderPopupAction(
                      value,
                      folderName,
                    ),
                    itemBuilder: (_) => _buildFolderPopupMenu(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 文件夹弹出菜单项（列表与网格视图共用）
  List<PopupMenuEntry<String>> _buildFolderPopupMenu() {
    return const [
      PopupMenuItem(
        value: 'multiSelect',
        child: ListTile(
          key: Key('fm_folder_menu_multi_select'),
          leading: Icon(Icons.checklist, size: 20),
          title: Text('多选'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'open',
        child: ListTile(
          key: Key('fm_folder_menu_open'),
          leading: Icon(Icons.folder_open, size: 20),
          title: Text('打开'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'rename',
        child: ListTile(
          key: Key('fm_folder_menu_rename'),
          leading: Icon(Icons.edit, size: 20),
          title: Text('重命名'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'move',
        child: ListTile(
          key: Key('fm_folder_menu_move'),
          leading: Icon(Icons.drive_file_move, size: 20),
          title: Text('移动'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'copy',
        child: ListTile(
          key: Key('fm_folder_menu_copy'),
          leading: Icon(Icons.copy, size: 20),
          title: Text('复制'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'export',
        child: ListTile(
          key: Key('fm_folder_menu_export'),
          leading: Icon(Icons.file_download_outlined, size: 20),
          title: Text('导出'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          key: Key('fm_folder_menu_delete'),
          leading: Icon(Icons.delete, size: 20, color: Colors.red),
          title: Text('删除', style: TextStyle(color: Colors.red)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  /// 文件夹弹出菜单动作（列表与网格视图共用）
  void _onFolderPopupAction(String value, String folderName) {
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
        _renameFile(file.id, file.name, file.format);
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

  Future<void> _renameFile(
    String fileId,
    String currentName,
    String format,
  ) async {
    _renameController.text = currentName;

    // 文本类型文件（格式在可切换列表中）在重命名时显示格式下拉框，
    // 与创建页一致，仅限那几种格式之间切换。页面未提供
    // onRenameFileWithFormat 时不显示（否则格式变更会被静默丢弃）
    final formatOptions = widget.config.renameFormatOptions;
    final showFormatDropdown = formatOptions != null &&
        formatOptions.contains(format) &&
        widget.onRenameFileWithFormat != null;

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => _RenameFileDialog(
        controller: _renameController,
        showFormatDropdown: showFormatDropdown,
        initialFormat: format,
        formatOptions: formatOptions ?? const [],
      ),
    );
    // 无论成功与否都清理输入，避免残留到下次打开对话框
    _renameController.clear();

    if (result == null) return;
    if (!mounted) return;
    final rawName = result.$1.trim();
    final newFormat = result.$2;
    // 名称与格式都未修改时视为无操作。
    // 注意：存储名可能以 .$format 结尾（如导入 report.txt.txt 时
    // 存储名为 report.txt），此时必须在剥离扩展名之前判断，
    // 否则「确认未修改」会被误判为真正的重命名
    if (rawName == currentName && newFormat == format) return;
    var newName = rawName;
    // 用户输入了带扩展名的名称（如把 report.txt 改成 report.md 时
    // 显示名会变成 report.md.txt）→ 剥离与当前格式重复的扩展名；
    // 同时剥离与下拉框新选的格式重复的扩展名（输入 report.md 并选
    // 择 md 时显示名不应变成 report.md.md）。
    // 仅在名称确实被修改时剥离：存储名本身以 .$format 结尾（导入
    // 场景）且只切换格式时，名称中的 .txt 是名字的一部分，不能剥掉
    if (rawName != currentName) {
      if (newName.endsWith('.$format')) {
        newName = newName.substring(0, newName.length - format.length - 1);
      }
      if (newFormat != format && newName.endsWith('.$newFormat')) {
        newName = newName.substring(0, newName.length - newFormat.length - 1);
      }
    }
    // 输入完整显示名（含扩展名）且剥离后与原名相同 → 无操作
    if (newName == currentName && newFormat == format) return;

    // 文件名校验：拒绝空名/超长/路径分隔符与 Windows 非法字符，
    // 否则非法文件名会在导出时引发路径错误
    final nameError = widget.manifestBridge.validateFileName(newName);
    if (nameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nameError),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Conflict check：显示名是 name.format，因此同文件夹下
    // 名称与格式都相同才算冲突（同名不同格式可共存，如 report.txt 与
    // report.md）。重命名时通过下拉框切换格式的场景尤其依赖此判断。
    final conflict = widget.sortedRecords.any(
      (r) =>
          r.name == newName &&
          r.format == newFormat &&
          r.folder == _currentFolder &&
          r.id != fileId,
    );
    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件 "$newName.$newFormat" 已存在'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    try {
      final onRenameWithFormat = widget.onRenameFileWithFormat;
      if (showFormatDropdown && onRenameWithFormat != null) {
        await onRenameWithFormat(fileId, newName, newFormat);
      } else {
        await widget.onRenameFile(fileId, newName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重命名失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
  }

  Future<void> _moveFile(String fileId) async {
    final (selectedFolder, _) = await _showFolderPickerDialog(
      widget.folders,
      title: '选择目标文件夹',
    );
    if (selectedFolder != null) {
      if (!mounted) return;
      final source = widget.sortedRecords.where((r) => r.id == fileId);
      // 目标为文件当前所在文件夹 → 无操作，提示用户
      if (source.isNotEmpty && source.first.folder == selectedFolder) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件已在目标位置'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (mounted) setState(() {});
        return;
      }
      // 目标文件夹已存在同名文件 → 拒绝移动，避免产生
      // 无法通过重命名解决的永久重复记录
      if (source.isNotEmpty &&
          widget.sortedRecords.any(
            (r) =>
                r.id != fileId &&
                r.folder == selectedFolder &&
                r.name == source.first.name,
          )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('目标文件夹已存在同名文件，移动已取消'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (mounted) setState(() {});
        return;
      }
      try {
        await widget.onMoveFile(fileId, selectedFolder);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('移动失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (mounted) setState(() {});
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _copyFile(String fileId) async {
    final (selectedFolder, _) = await _showFolderPickerDialog(
      widget.folders,
      title: '选择复制到的目标文件夹',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    try {
      await widget.onCopyFile(fileId, selectedFolder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (mounted) setState(() {});
      return;
    }
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
      try {
        await widget.onDeleteFile(fileId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
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

  /// 从批量操作列表中移除“包含在其他已选文件夹内”的文件夹。
  /// 避免同一子树被重复移动/复制/删除（例如同时选中 a 和 a/b 时
  /// 只处理 a，a/b 随 a 一并处理）。
  List<String> _topLevelFolders(List<String> folderNames) {
    return folderNames
        .where(
          (name) => !folderNames.any(
            (other) => other != name && name.startsWith('$other/'),
          ),
        )
        .toList();
  }

  /// 校验批量移动/复制后各文件夹的新路径：
  /// - 目标位置位于源文件夹自身或其子树内（如内嵌面板中新建了同名文件夹）
  /// - 目标位置（或其下）已存在同名文件夹（会造成静默合并/重复复制）
  /// - 所选文件夹之间同名冲突（如 a/x 与 b/x 同时移入 t）
  /// - 原地不动（新路径 == 源路径）
  /// 命中任一情况时提示用户并返回 false。
  /// [liveFolders] 是文件夹选择面板会话结束时的实时集合
  /// （包含面板内新建的文件夹），[widget.folders] 可能已过期。
  bool _validateFolderTargets(
    List<String> folderNames,
    String targetFolder,
    Set<String> liveFolders,
  ) {
    final seen = <String>{};
    for (final name in folderNames) {
      final base = widget.manifestBridge.getFolderBaseName(name);
      final newPath = targetFolder.isEmpty ? base : '$targetFolder/$base';
      final invalid = newPath == name ||
          targetFolder == name ||
          targetFolder.startsWith('$name/') ||
          liveFolders.any((f) => f == newPath || f.startsWith('$newPath/')) ||
          !seen.add(newPath);
      if (invalid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newPath == name
                    ? '文件夹已在目标位置，操作已取消'
                    : '所选文件夹在目标位置存在同名冲突或位于自身内部，操作已取消',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('fm_delete_selected_dialog'),
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 项吗？此操作不可恢复。'),
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
      // 只处理顶层已选文件夹，避免子树被重复删除
      final topLevelFolders = _topLevelFolders(folderNames);
      final adjustedFileIds = _fileIdsExcludingFolderFiles(
        fileIds,
        topLevelFolders,
      );
      try {
        if (adjustedFileIds.isNotEmpty) {
          await widget.onDeleteFiles(adjustedFileIds);
        }
        if (topLevelFolders.isNotEmpty) {
          await widget.onDeleteFolders(topLevelFolders);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('批量删除失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
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
    // 只导出顶层已选文件夹（其子文件夹内容由递归导出覆盖）
    final topLevelFolders = _topLevelFolders(folderNames);
    final adjustedFileIds = _fileIdsExcludingFolderFiles(
      fileIds,
      topLevelFolders,
    );

    // 第一次导出选择的目录会传递给后续导出，
    // 避免混合选择（文件+文件夹）时弹出两次目录选择
    String? chosenDir;

    // Export files
    if (adjustedFileIds.isNotEmpty && widget.onExportFiles != null) {
      chosenDir = await widget.onExportFiles!(adjustedFileIds, '');
    }

    // Export folders — prefer the batch callback, fall back to per-folder
    if (topLevelFolders.isNotEmpty && widget.onExportFolders != null) {
      final foldersDir = await widget.onExportFolders!(
        topLevelFolders,
        chosenDir ?? '',
      );
      chosenDir = chosenDir ?? foldersDir;
    } else {
      for (final name in topLevelFolders) {
        if (widget.onExportFolder != null) {
          final folderDir = await widget.onExportFolder!(name);
          chosenDir = chosenDir ?? folderDir;
        }
      }
    }

    // 仅在确实导出过内容时退出选择模式；取消目录选择时保留选择
    if (chosenDir != null) {
      _exitSelectionMode();
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportFolder(String folderName) async {
    if (widget.onExportFolder != null) {
      await widget.onExportFolder!(folderName);
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty) return;

    final fileIds = <String>[];
    final folderNames = <String>[];
    for (final id in _selectedIds) {
      if (widget.folders.contains(id)) {
        folderNames.add(id);
      } else {
        fileIds.add(id);
      }
    }
    // 只处理顶层已选文件夹，避免子树被重复移动
    final topLevelFolders = _topLevelFolders(folderNames);

    // 排除已选文件夹及其后代，防止把文件夹移入自身/子文件夹造成循环
    final excluded = <String>{};
    for (final name in topLevelFolders) {
      excluded.add(name);
      excluded.addAll(
        widget.manifestBridge.getAllDescendantFolderPaths(
          name,
          widget.folders,
        ),
      );
    }
    final targetFolders =
        widget.folders.where((f) => !excluded.contains(f)).toSet();

    final (selectedFolder, liveFolders) = await _showFolderPickerDialog(
      targetFolders,
      title: '选择目标文件夹',
    );

    if (selectedFolder != null) {
      if (!mounted) return;
      // 同名冲突或原地不动时取消整批操作
      if (!_validateFolderTargets(
        topLevelFolders,
        selectedFolder,
        liveFolders,
      )) {
        return;
      }
      final adjustedFileIds = _fileIdsExcludingFolderFiles(
        fileIds,
        topLevelFolders,
      );
      // 部分文件已位于目标文件夹 → 无操作，提示用户
      final alreadyThere = adjustedFileIds.any((id) {
        final matches = widget.sortedRecords.where((r) => r.id == id);
        return matches.isNotEmpty && matches.first.folder == selectedFolder;
      });
      if (alreadyThere) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('所选文件已在目标位置，移动已取消'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      // 目标文件夹已存在同名文件、或批内两个被移动文件同名
      // （选择模式支持跨文件夹选择，不同文件夹允许同名文件）→ 拒绝，
      // 避免产生无法通过重命名解决的永久重复记录
      final movedNames = <String>{};
      final nameConflict = adjustedFileIds.any((id) {
        final matches = widget.sortedRecords.where((r) => r.id == id);
        if (matches.isEmpty) return false;
        final name = matches.first.name;
        if (!movedNames.add(name)) return true; // 批内同名冲突
        return widget.sortedRecords.any(
          (r) => r.id != id && r.folder == selectedFolder && r.name == name,
        );
      });
      if (nameConflict) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('目标文件夹已存在同名文件，移动已取消'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      // 先移动文件夹再移动文件：文件夹操作被拒绝/失败时
      // 文件尚未移动，避免出现部分执行
      try {
        if (topLevelFolders.isNotEmpty) {
          await widget.onMoveFolders(topLevelFolders, selectedFolder);
        }
        if (adjustedFileIds.isNotEmpty) {
          await widget.onMoveFiles(adjustedFileIds, selectedFolder);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('批量移动失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      _exitSelectionMode();
    }
    if (mounted) setState(() {});
  }

  Future<void> _copySelected() async {
    if (_selectedIds.isEmpty) return;

    final fileIds = <String>[];
    final folderNames = <String>[];
    for (final id in _selectedIds) {
      if (widget.folders.contains(id)) {
        folderNames.add(id);
      } else {
        fileIds.add(id);
      }
    }
    // 只处理顶层已选文件夹，避免子树被重复复制
    final topLevelFolders = _topLevelFolders(folderNames);

    // 排除已选文件夹及其后代，防止把文件夹复制到自身/子文件夹中
    final excluded = <String>{};
    for (final name in topLevelFolders) {
      excluded.add(name);
      excluded.addAll(
        widget.manifestBridge.getAllDescendantFolderPaths(
          name,
          widget.folders,
        ),
      );
    }
    final targetFolders =
        widget.folders.where((f) => !excluded.contains(f)).toSet();

    final (selectedFolder, liveFolders) = await _showFolderPickerDialog(
      targetFolders,
      title: '选择目标文件夹',
    );

    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    // 同名冲突或原地不动时取消整批操作
    if (!_validateFolderTargets(
      topLevelFolders,
      selectedFolder,
      liveFolders,
    )) {
      return;
    }
    final adjustedFileIds = _fileIdsExcludingFolderFiles(
      fileIds,
      topLevelFolders,
    );
    // 批内两个被复制文件同名（选择模式支持跨文件夹选择，
    // 不同文件夹允许同名文件）时，各页面的 _副本 去重基于
    // 快照并发计算，会生成同名副本 → 拒绝整批复制
    final copiedNames = <String>{};
    final nameConflict = adjustedFileIds.any((id) {
      final matches = widget.sortedRecords.where((r) => r.id == id);
      if (matches.isEmpty) return false;
      return !copiedNames.add(matches.first.name);
    });
    if (nameConflict) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所选文件中存在同名文件，复制已取消（请逐个复制）'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    // 先复制文件夹再复制文件。文件夹逐个顺序复制：
    // 失败时中止，避免文件夹失败后文件仍被复制（已完成的文件夹保留）
    try {
      for (final name in topLevelFolders) {
        await widget.onCopyFolder(name, selectedFolder);
      }
      await Future.wait(
        adjustedFileIds.map((id) => widget.onCopyFile(id, selectedFolder)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('批量复制失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    _exitSelectionMode();
    if (mounted) setState(() {});
  }

  Future<void> _renameSelected() async {
    if (_selectedIds.isEmpty) return;

    final fileIds = <String>[];
    final folderNames = <String>[];
    for (final id in _selectedIds) {
      if (widget.folders.contains(id)) {
        folderNames.add(id);
      } else {
        fileIds.add(id);
      }
    }
    final selectedFiles =
        widget.sortedRecords.where((r) => fileIds.contains(r.id)).toList();

    final plan = await showBatchRenameDialog<T>(
      context: context,
      selectedFiles: selectedFiles,
      selectedFolders: folderNames,
      allRecords: widget.sortedRecords,
      allFolders: widget.folders,
      bridge: widget.manifestBridge,
      initialSort: widget.sortConfig,
    );
    if (plan == null || !mounted) return;
    await _applyBatchRenamePlan(plan);
  }

  /// 按计划应用批量重命名。文件夹先于文件执行（计划已排好安全顺序）。
  Future<void> _applyBatchRenamePlan(BatchRenamePlan plan) async {
    var applied = 0;
    var failed = 0;
    for (final entry in plan.folderEntries) {
      try {
        await widget.onRenameFolder(entry.id, entry.newBaseName);
        applied++;
      } catch (_) {
        failed++;
      }
    }
    for (final entry in plan.fileEntries) {
      try {
        await widget.onRenameFile(entry.id, entry.newBaseName);
        applied++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0 ? '已重命名 $applied 项' : '重命名完成：成功 $applied 项，失败 $failed 项',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
              // 总是弹出对话框：名称校验在关闭后进行（SnackBar 提示），
              // 避免按钮无响应让用户困惑（含空名称）
              Navigator.pop(ctx, _folderNameController.text.trim());
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    // 无论成功与否都清空输入，避免上次的文本残留到下次打开对话框
    _folderNameController.clear();

    if (result != null) {
      // 空名称（含纯空白）由 validateFolderName 统一提示
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
      // Prepend the current folder path to create subfolder hierarchy
      final fullPath =
          _currentFolder.isEmpty ? result : '$_currentFolder/$result';
      // 重名检查：与内嵌文件夹选择面板行为保持一致
      if (widget.folders.contains(fullPath)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件夹已存在'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      try {
        await widget.onCreateFolder(fullPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('创建文件夹失败: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      // If we're at root, navigate into the newly created folder
      if (!mounted) return;
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
    // 预填基础名而不是完整路径，避免用户手动删除路径前缀
    _renameController.text = widget.manifestBridge.getFolderBaseName(
      folderName,
    );
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
              // 总是弹出对话框：名称校验在关闭后进行（SnackBar 提示），
              // 避免按钮无响应让用户困惑（含空名称）
              Navigator.pop(ctx, _renameController.text.trim());
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
    _renameController.clear();

    // 与预填的基础名比较（或用户直接输入了完整旧路径）：
    // 未修改名称时视为无操作，否则会把 baseName 当作完整路径传给
    // provider 触发重命名，而无操作重命名会触发
    // removeFolder/removeFolderFromCache 导致数据丢失
    if (result != null &&
        result != widget.manifestBridge.getFolderBaseName(folderName) &&
        result != folderName) {
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
      // 目标位置（或其下）已存在同名文件夹：拒绝，避免静默合并两个文件夹
      final parentPath = widget.manifestBridge.getParentFolderPath(
        folderName,
      );
      final newFullPath = parentPath.isEmpty ? result : '$parentPath/$result';
      if (widget.folders.any(
        (f) => f == newFullPath || f.startsWith('$newFullPath/'),
      )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('目标位置已存在同名文件夹，操作已取消'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      try {
        await widget.onRenameFolder(folderName, result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('重命名失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      // 注：弹出菜单只能作用于当前文件夹的直接子文件夹，
      // 因此无需处理「重命名的文件夹包含当前浏览位置」的情况
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

    final (selectedFolder, liveFolders) = await _showFolderPickerDialog(
      targetFolders,
      title: '移动文件夹到…',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    // 目标为当前位置（父目录/根目录）时属于无操作，提示用户
    if (widget.manifestBridge.getParentFolderPath(folderName) ==
        selectedFolder) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件夹已在目标位置'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    // 目标位于自身/子树内（如内嵌面板中新建了同名文件夹），
    // 或目标位置已存在同名文件夹（会静默合并），均拒绝执行
    final base = widget.manifestBridge.getFolderBaseName(folderName);
    final prospectivePath =
        selectedFolder.isEmpty ? base : '$selectedFolder/$base';
    if (selectedFolder == folderName ||
        selectedFolder.startsWith('$folderName/') ||
        liveFolders.any(
          (f) => f == prospectivePath || f.startsWith('$prospectivePath/'),
        )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('目标位置已存在同名文件夹或为文件夹自身，操作已取消'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    try {
      await widget.onMoveFolder(folderName, selectedFolder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移动失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
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

    final (selectedFolder, liveFolders) = await _showFolderPickerDialog(
      targetFolders,
      title: '复制文件夹到…',
    );
    if (selectedFolder == null) {
      if (mounted) setState(() {});
      return;
    }

    // 目标为当前位置（父目录/根目录）时属于无操作，提示用户
    if (widget.manifestBridge.getParentFolderPath(folderName) ==
        selectedFolder) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件夹已在目标位置'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    // 目标位于自身/子树内（如内嵌面板中新建了同名文件夹），
    // 或目标位置已存在同名文件夹（会造成重复复制），均拒绝执行
    final base = widget.manifestBridge.getFolderBaseName(folderName);
    final prospectivePath =
        selectedFolder.isEmpty ? base : '$selectedFolder/$base';
    if (selectedFolder == folderName ||
        selectedFolder.startsWith('$folderName/') ||
        liveFolders.any(
          (f) => f == prospectivePath || f.startsWith('$prospectivePath/'),
        )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('目标位置已存在同名文件夹或为文件夹自身，操作已取消'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    try {
      await widget.onCopyFolder(folderName, selectedFolder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
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
      try {
        await widget.onDeleteFolder(folderName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      if (_currentFolder == folderName) {
        _setCurrentFolder(
          widget.manifestBridge.getParentFolderPath(folderName),
        );
      }
    }
  }

  Future<void> _refreshFileList() async {
    try {
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
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
  // Folder picker dialog (shared [FolderPickerDialog], same as OCR page)
  // ====================================================================

  /// 显示统一的目标文件夹选择面板（与文字识别页共用的 [FolderPickerDialog]）。
  /// 返回 (选中的文件夹路径, 面板会话结束时的实时文件夹集合)。实时集合包含
  /// 面板内新建的文件夹 —— 调用方需要用它对目标冲突做校验，因为
  /// [widget.folders] 是构建时冻结的集合。
  Future<(String?, Set<String>)> _showFolderPickerDialog(
    Set<String> folders, {
    String title = '选择目标文件夹',
  }) async {
    // 面板会话内新建的文件夹路径（用于返回实时集合做冲突校验）
    final createdFolders = <String>{};

    final selectedFolder = await FolderPickerDialog.show(
      context,
      availableFolders: folders,
      title: title,
      onCreateFolder: (name) async {
        try {
          await widget.onCreateFolder(name);
          createdFolders.add(name);
          return null;
        } catch (e) {
          return '创建文件夹失败: $e';
        }
      },
      onRefreshFolders: () async => {...folders, ...createdFolders},
    );

    if (selectedFolder == null) return (null, Set<String>.from(folders));
    return (selectedFolder, {...folders, ...createdFolders});
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
}

// ====================================================================
// 文件重命名对话框
//
// 文本类型文件（txt/md/mmd）额外显示格式下拉框，与创建页一致，
// 让用户可以在那几种格式之间切换后缀。
// ====================================================================

class _RenameFileDialog extends StatefulWidget {
  final TextEditingController controller;
  final bool showFormatDropdown;
  final String initialFormat;
  final List<String> formatOptions;

  const _RenameFileDialog({
    required this.controller,
    required this.showFormatDropdown,
    required this.initialFormat,
    this.formatOptions = const [],
  });

  @override
  State<_RenameFileDialog> createState() => _RenameFileDialogState();
}

class _RenameFileDialogState extends State<_RenameFileDialog> {
  late String _selectedFormat = widget.initialFormat;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('fm_rename_file_dialog'),
      title: const Text('重命名文件'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('fm_rename_file_input'),
              controller: widget.controller,
              decoration: const InputDecoration(
                hintText: '输入新名称',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.showFormatDropdown) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('fm_rename_file_format_dropdown'),
                initialValue: _selectedFormat,
                decoration: const InputDecoration(
                  labelText: '格式',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: widget.formatOptions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedFormat = value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('fm_rename_cancel_btn'),
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          key: const Key('fm_rename_confirm_btn'),
          onPressed: () {
            // 总是弹出对话框：名称校验在关闭后进行（SnackBar 提示），
            // 避免按钮无响应让用户困惑（含空名称）
            Navigator.pop(
              context,
              (widget.controller.text.trim(), _selectedFormat),
            );
          },
          child: const Text('重命名'),
        ),
      ],
    );
  }
}
