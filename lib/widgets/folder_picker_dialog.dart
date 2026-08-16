import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/folder_path_utils.dart';
import '../utils/natural_sort.dart';

/// 文件夹选择器对话框
///
/// 单击选中文件夹，双击进入查看子文件夹；支持在子文件夹内
/// 创建新文件夹（创建在完整路径下）。
/// 支持创建新文件夹后自动刷新列表。
/// 可选的 [fileNameController] 用于在对话框中输入文件名。
class FolderPickerDialog extends StatefulWidget {
  /// 当前选中的文件夹
  final String currentFolder;

  /// 初始的现有文件夹列表
  final Set<String> availableFolders;

  /// 创建新文件夹的回调（返回错误信息或 null 表示成功）
  final Future<String?> Function(String name)? onCreateFolder;

  /// 刷新文件夹列表的回调（返回最新的文件夹集合）
  final Future<Set<String>> Function()? onRefreshFolders;

  /// 对话框标题
  final String title;

  /// 自定义提示文字（显示在标题下方）。若为空则使用默认提示。
  final String? hintText;

  /// 可选的文件名输入控制器。设置后在对话框顶部显示文件名输入字段。
  final TextEditingController? fileNameController;

  /// 文件名输入框的提示文字
  final String? fileNameHintText;

  const FolderPickerDialog({
    super.key,
    this.currentFolder = '',
    this.availableFolders = const {},
    this.onCreateFolder,
    this.onRefreshFolders,
    this.title = '选择文件夹',
    this.hintText,
    this.fileNameController,
    this.fileNameHintText,
  });

  /// 便捷方法：展示文件夹选择对话框
  static Future<String?> show(
    BuildContext context, {
    String currentFolder = '',
    Set<String> availableFolders = const {},
    Future<String?> Function(String name)? onCreateFolder,
    Future<Set<String>> Function()? onRefreshFolders,
    String title = '选择文件夹',
    String? hintText,
    TextEditingController? fileNameController,
    String? fileNameHintText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => FolderPickerDialog(
        currentFolder: currentFolder,
        availableFolders: availableFolders,
        onCreateFolder: onCreateFolder,
        onRefreshFolders: onRefreshFolders,
        title: title,
        hintText: hintText,
        fileNameController: fileNameController,
        fileNameHintText: fileNameHintText,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  String _selectedFolder = '';
  String _currentPath = '';
  Set<String> _availableFolders = {};
  final _newFolderController = TextEditingController();
  final _newFolderFocusNode = FocusNode();
  bool _showNewFolderInput = false; // 是否显示新建文件夹的输入行（默认只显示按钮）
  bool _isCreating = false;
  String? _createError;

  // 双击检测：第一次点击立即更新 UI，第二次点击在超时内则视为双击。
  Timer? _doubleTapTimer;
  String? _lastTappedFolder;

  @override
  void initState() {
    super.initState();
    _selectedFolder = widget.currentFolder;
    _availableFolders = Set.from(widget.availableFolders);
  }

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    _newFolderController.dispose();
    _newFolderFocusNode.dispose();
    super.dispose();
  }

  /// 获取当前路径下的直接子文件夹（排序后）
  ///
  /// 不包含当前目录自身 —— 当前目录在子文件夹层级下作为独立的
  /// "当前文件夹"层级显示（见 build），否则当前目录会与它的
  /// 子文件夹同层级并列，层级关系混乱。
  List<String> get _filteredFolders {
    // 根目录（''）由固定的"根目录"行表示，不进入列表重复列出
    return FolderPathUtils.getChildFolderPaths(_currentPath, _availableFolders)
      ..removeWhere((p) => p.isEmpty)
      ..sort(compareNatural);
  }

  /// 判断当前是否在子文件夹中
  bool get _isInSubFolder => _currentPath.isNotEmpty;

  /// 进入子文件夹（同时自动选中该文件夹）
  void _navigateInto(String folderPath) {
    setState(() {
      _currentPath = folderPath;
      _selectedFolder = folderPath;
      _createError = null;
    });
  }

  /// 返回上级（同时将选中项更新为返回后的文件夹）
  void _navigateBack() {
    setState(() {
      final idx = _currentPath.lastIndexOf('/');
      _currentPath = idx == -1 ? '' : _currentPath.substring(0, idx);
      _selectedFolder = _currentPath;
      _createError = null;
    });
  }

  /// 点击「创建新文件夹」按钮：显示输入行并聚焦
  void _startNewFolder() {
    setState(() {
      _showNewFolderInput = true;
      _newFolderController.clear();
      _createError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newFolderFocusNode.requestFocus();
    });
  }

  /// 点击输入行右侧的 ✕：放弃新建，恢复为按钮状态
  void _cancelNewFolder() {
    setState(() {
      _showNewFolderInput = false;
      _newFolderController.clear();
      _createError = null;
    });
  }

  Future<void> _createFolder() async {
    if (_isCreating) return; // 防止回车+按钮等重复触发
    final name = _newFolderController.text.trim();
    // 与 manifest 保持一致的文件名校验（空名/超长/斜杠），
    // 避免创建出在 manifest 中无效（被静默忽略）的文件夹路径
    final validationError = FolderPathUtils.validateFolderName(name);
    if (validationError != null) {
      setState(() => _createError = validationError);
      return;
    }

    // 在子文件夹内创建时使用完整路径，避免文件夹被错误创建到根目录
    final fullPath = _currentPath.isEmpty ? name : '$_currentPath/$name';

    if (_availableFolders.contains(fullPath)) {
      setState(() => _createError = '文件夹已存在');
      return;
    }

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    if (widget.onCreateFolder != null) {
      String? error;
      try {
        error = await widget.onCreateFolder!(fullPath);
      } catch (e) {
        // 回调抛异常时也要复位 _isCreating，否则创建按钮会一直禁用
        if (mounted) {
          setState(() {
            _isCreating = false;
            _createError = '创建文件夹失败: $e';
          });
        }
        return;
      }
      if (error != null) {
        if (mounted) {
          setState(() {
            _isCreating = false;
            _createError = error;
          });
        }
        return;
      }
    }

    // 创建成功后刷新文件夹列表
    if (widget.onRefreshFolders != null) {
      Set<String> updatedFolders;
      try {
        updatedFolders = await widget.onRefreshFolders!();
      } catch (e) {
        // 刷新失败也要复位 _isCreating，否则创建按钮会一直禁用
        if (mounted) {
          setState(() {
            _isCreating = false;
            _createError = '刷新文件夹列表失败: $e';
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _availableFolders = updatedFolders;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isCreating = false;
        _newFolderController.clear();
        _createError = null;
        // 创建成功后把选择更新为新文件夹
        _selectedFolder = fullPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final folders = _filteredFolders;

    return PopScope(
      // 创建进行中禁止通过返回键/点遮罩/ESC 关闭对话框：
      // 避免文件夹已创建但调用方收到「取消」
      canPop: !_isCreating,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            const SizedBox(height: 4),
            Text(
              widget.hintText ?? '单击选中，双击进入查看子文件夹',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        // 内容区可滚动：键盘弹出或列表过长时不会溢出裁剪输入行
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 文件名输入（可选）
                if (widget.fileNameController != null) ...[
                  Text(
                    '文件名',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: widget.fileNameController,
                    decoration: InputDecoration(
                      hintText: widget.fileNameHintText ?? '输入文件名',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                ],
                // 路径导航栏
                if (_isInSubFolder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20),
                          onPressed: _navigateBack,
                          visualDensity: VisualDensity.compact,
                          tooltip: '返回上级',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '根目录 > $_currentPath',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 根目录选项（仅根目录层级显示）
                if (!_isInSubFolder)
                  _buildFolderTile(
                    context,
                    cs,
                    '',
                    '根目录',
                    Icons.home_outlined,
                  ),

                // 当前文件夹层级（仅子文件夹层级显示）：当前目录作为
                // 独立层级呈现，不混入"子文件夹"列表 —— 否则当前目录
                // 与它的子文件夹同层级并列，层级关系混乱。
                if (_isInSubFolder &&
                    _availableFolders.contains(_currentPath)) ...[
                  const SizedBox(height: 8),
                  _sectionLabel(context, '当前文件夹'),
                  const SizedBox(height: 4),
                  _buildFolderTile(
                    context,
                    cs,
                    _currentPath,
                    FolderPathUtils.getFolderBaseName(_currentPath),
                    Icons.folder_open,
                  ),
                ],

                // 现有文件夹列表
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionLabel(
                    context,
                    _isInSubFolder ? '子文件夹' : '现有文件夹',
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final folder in folders)
                          _buildFolderTile(
                            context,
                            cs,
                            folder,
                            // 显示文件夹基名（不含父路径）
                            _isInSubFolder
                                ? folder.substring(
                                    folder.lastIndexOf('/') + 1,
                                  )
                                : folder,
                            Icons.folder_outlined,
                          ),
                      ],
                    ),
                  ),
                ],

                // 创建新文件夹：仅当调用方支持创建时才显示。
                // 默认只显示按钮，点击后才展开输入行；
                // 输入行右侧的 ✕ 可放弃新建
                if (widget.onCreateFolder != null) ...[
                  const Divider(height: 24),
                  if (!_showNewFolderInput)
                    OutlinedButton.icon(
                      key: const Key('folder_picker_start_create_btn'),
                      onPressed: _startNewFolder,
                      icon: const Icon(Icons.create_new_folder_outlined,
                          size: 18),
                      label: const Text('创建新文件夹'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newFolderController,
                            focusNode: _newFolderFocusNode,
                            decoration: InputDecoration(
                              hintText: '输入文件夹名称',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: cs.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              errorText: _createError,
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _createFolder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            key: const Key('folder_picker_create_confirm_btn'),
                            onPressed: _isCreating ? null : _createFolder,
                            child: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add, size: 20),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ✕ 放弃新建：放在加号右侧
                        IconButton(
                          key: const Key('folder_picker_cancel_create_btn'),
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: '取消新建',
                          visualDensity: VisualDensity.compact,
                          onPressed: _isCreating ? null : _cancelNewFolder,
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            // 创建进行中禁用：避免在途创建时直接关闭对话框，
            // 导致文件夹已创建但调用方收到「取消」
            onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            // 创建进行中禁用：避免在途创建时弹出旧选择
            onPressed: _isCreating
                ? null
                : () => Navigator.of(context).pop(_selectedFolder),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 列表分组标题（如"现有文件夹 / 子文件夹 / 当前文件夹"）
  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildFolderTile(
    BuildContext context,
    ColorScheme cs,
    String folder,
    String displayName,
    IconData icon,
  ) {
    final isSelected = _selectedFolder == folder;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // 先上 UI：立即更新选中状态
            setState(() => _selectedFolder = folder);

            // 再检测是否构成双击（在超时内再次点击同一文件夹）
            final isDoubleTap = _lastTappedFolder == folder &&
                _doubleTapTimer != null &&
                _doubleTapTimer!.isActive;

            _doubleTapTimer?.cancel();
            _doubleTapTimer = null;
            _lastTappedFolder = null;

            if (isDoubleTap) {
              // 视为双击 - 进入文件夹
              if (folder.isNotEmpty) {
                _navigateInto(folder);
              }
            } else {
              // 第一次点击 - 启动双击等待计时器
              _lastTappedFolder = folder;
              _doubleTapTimer = Timer(
                const Duration(milliseconds: 300),
                () {
                  _doubleTapTimer = null;
                  _lastTappedFolder = null;
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check, size: 18, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
