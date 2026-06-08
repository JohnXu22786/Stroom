import 'package:flutter/material.dart';

/// 文件夹选择器对话框
///
/// 显示现有文件夹列表并提供创建新文件夹的功能。
/// 返回用户选择的文件夹路径（空字符串表示根目录）。
class FolderPickerDialog extends StatefulWidget {
  /// 当前选中的文件夹
  final String currentFolder;

  /// 现有文件夹列表
  final Set<String> availableFolders;

  /// 创建新文件夹的回调（返回错误信息或 null 表示成功）
  final Future<String?> Function(String name)? onCreateFolder;

  /// 对话框标题
  final String title;

  const FolderPickerDialog({
    super.key,
    this.currentFolder = '',
    this.availableFolders = const {},
    this.onCreateFolder,
    this.title = '选择文件夹',
  });

  /// 便捷方法：展示文件夹选择对话框
  static Future<String?> show(
    BuildContext context, {
    String currentFolder = '',
    Set<String> availableFolders = const {},
    Future<String?> Function(String name)? onCreateFolder,
    String title = '选择文件夹',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => FolderPickerDialog(
        currentFolder: currentFolder,
        availableFolders: availableFolders,
        onCreateFolder: onCreateFolder,
        title: title,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  String _selectedFolder = '';
  final _newFolderController = TextEditingController();
  bool _isCreating = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _selectedFolder = widget.currentFolder;
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  List<String> get _sortedFolders {
    final folders = widget.availableFolders.toList();
    folders.sort((a, b) {
      // 根目录（空字符串）排在最前
      if (a.isEmpty) return -1;
      if (b.isEmpty) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return folders;
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

    if (widget.availableFolders.contains(name)) {
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

    if (mounted) {
      setState(() {
        _selectedFolder = name;
        _isCreating = false;
        _newFolderController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 根目录选项
            _buildFolderTile(context, cs, '', '根目录', Icons.home_outlined),

            // 现有文件夹列表
            if (_sortedFolders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '现有文件夹',
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
                    for (final folder in _sortedFolders)
                      if (folder.isNotEmpty)
                        _buildFolderTile(
                            context, cs, folder, folder, Icons.folder_outlined),
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
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
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
    );
  }
}
