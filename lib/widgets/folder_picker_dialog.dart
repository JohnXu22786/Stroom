import 'package:flutter/material.dart';

/// 文件夹选择器对话框
///
/// 显示根目录级别的文件夹列表（不含次级子文件夹）。
/// 单击选中文件夹，双击进入查看子文件夹。
/// 支持创建新文件夹后自动刷新列表。
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

  const FolderPickerDialog({
    super.key,
    this.currentFolder = '',
    this.availableFolders = const {},
    this.onCreateFolder,
    this.onRefreshFolders,
    this.title = '选择文件夹',
    this.hintText,
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
  bool _isCreating = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _selectedFolder = widget.currentFolder;
    _availableFolders = Set.from(widget.availableFolders);
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  /// 获取当前路径下的直接子文件夹（排序后）
  List<String> get _filteredFolders {
    final prefix = _currentPath.isEmpty ? '' : '$_currentPath/';
    final result = <String>[];
    for (final f in _availableFolders) {
      if (f == _currentPath) continue;
      if (_currentPath.isEmpty) {
        // 根目录：只显示顶级文件夹（不含 /）
        if (!f.contains('/')) result.add(f);
      } else {
        if (f.startsWith(prefix)) {
          final suffix = f.substring(prefix.length);
          // 直接子级：不含额外的 /
          if (!suffix.contains('/')) result.add(f);
        }
      }
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  /// 判断当前是否在子文件夹中
  bool get _isInSubFolder => _currentPath.isNotEmpty;

  /// 进入子文件夹
  void _navigateInto(String folderPath) {
    setState(() {
      _currentPath = folderPath;
    });
  }

  /// 返回上级
  void _navigateBack() {
    setState(() {
      final idx = _currentPath.lastIndexOf('/');
      _currentPath = idx == -1 ? '' : _currentPath.substring(0, idx);
    });
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = '文件夹名不能为空');
      return;
    }

    if (name.contains('/')) {
      setState(() => _createError = '文件夹名不能包含斜杠 /');
      return;
    }

    if (_availableFolders.contains(name)) {
      setState(() => _createError = '文件夹已存在');
      return;
    }

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    if (widget.onCreateFolder != null) {
      final error = await widget.onCreateFolder!(name);
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
      final updatedFolders = await widget.onRefreshFolders!();
      if (mounted) {
        setState(() {
          _availableFolders = updatedFolders;
        });
      }
    }

    if (mounted) {
      setState(() {
        _selectedFolder = name;
        _isCreating = false;
        _newFolderController.clear();
        _createError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final folders = _filteredFolders;

    return AlertDialog(
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
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                            .bodySmall
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

            // 现有文件夹列表
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _isInSubFolder ? '子文件夹' : '现有文件夹',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
                            ? folder.substring(_currentPath.length + 1)
                            : folder,
                        Icons.folder_outlined,
                      ),
                  ],
                ),
              ),
            ],

            const Divider(height: 24),

            // 创建新文件夹
            Text(
              '创建新文件夹',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderController,
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
                    onPressed: _isCreating ? null : _createFolder,
                    child: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedFolder),
          child: const Text('确定'),
        ),
      ],
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
      child: GestureDetector(
        onDoubleTap: () {
          if (folder.isNotEmpty) {
            _navigateInto(folder);
          }
        },
        child: Material(
          color: isSelected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedFolder = folder),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? cs.onPrimaryContainer : cs.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
