import 'package:flutter/material.dart';
import 'folder_picker_dialog.dart';

enum CameraChoice { app, system }

/// 相机选择对话框的返回结果
class CameraChoiceResult {
  final CameraChoice choice;
  final String folder;
  final bool editAfterCapture;

  const CameraChoiceResult({
    required this.choice,
    this.folder = '',
    this.editAfterCapture = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraChoiceResult &&
          choice == other.choice &&
          folder == other.folder &&
          editAfterCapture == other.editAfterCapture;

  @override
  int get hashCode => Object.hash(choice, folder, editAfterCapture);
}

/// 显示拍照方式选择弹窗（统一使用文件页面样式）
///
/// [initialFolder] 初始选中的文件夹（默认根目录）
/// [availableFolders] 可选文件夹列表
/// [onCreateFolder] 创建新文件夹的回调（返回错误信息或 null 表示成功）
/// [showFolderSection] 是否显示文件夹选择和「拍完编辑」部分（在对话页面中隐藏）
Future<CameraChoiceResult?> showCameraChoiceDialog(
  BuildContext context, {
  String initialFolder = '',
  Set<String> availableFolders = const {},
  Future<String?> Function(String name)? onCreateFolder,
  bool showFolderSection = true,
}) {
  return showModalBottomSheet<CameraChoiceResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CameraChoiceSheet(
      initialFolder: initialFolder,
      availableFolders: availableFolders,
      onCreateFolder: onCreateFolder,
      showFolderSection: showFolderSection,
    ),
  );
}

class _CameraChoiceSheet extends StatefulWidget {
  final String initialFolder;
  final Set<String> availableFolders;
  final Future<String?> Function(String name)? onCreateFolder;
  final bool showFolderSection;

  const _CameraChoiceSheet({
    this.initialFolder = '',
    this.availableFolders = const {},
    this.onCreateFolder,
    this.showFolderSection = true,
  });

  @override
  State<_CameraChoiceSheet> createState() => _CameraChoiceSheetState();
}

class _CameraChoiceSheetState extends State<_CameraChoiceSheet> {
  late String _selectedFolder;
  bool _editAfterCapture = false;

  @override
  void initState() {
    super.initState();
    _selectedFolder = widget.initialFolder;
  }

  Future<void> _pickFolder() async {
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _selectedFolder,
      availableFolders: widget.availableFolders,
      onCreateFolder: widget.onCreateFolder,
      title: '拍照添加至文件夹',
    );
    if (result != null && mounted) {
      setState(() => _selectedFolder = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ──
            Text(
              '选择拍照方式',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // ── Camera choices (file-page style cards) ──
            // 应用相机
            _FileStyleChoiceCard(
              icon: Icons.camera_alt,
              title: '应用相机',
              subtitle: '使用应用内置相机，支持调整比例和压缩设置',
              color: Colors.orange,
              onTap: () => _onChoice(CameraChoice.app),
            ),
            const SizedBox(height: 8),

            // 系统相机
            _FileStyleChoiceCard(
              icon: Icons.phone_android,
              title: '系统相机',
              subtitle: '使用系统默认相机应用',
              color: Colors.blue,
              onTap: () => _onChoice(CameraChoice.system),
            ),
            const SizedBox(height: 20),

            // ── Folder selection section ──
            if (widget.showFolderSection) ...[
              // 添加至文件夹
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickFolder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.folder_outlined,
                                size: 20, color: Colors.amber),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '添加至文件夹',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                        color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedFolder.isEmpty
                                    ? '根目录'
                                    : _selectedFolder,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 拍完编辑
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.edit_outlined,
                              size: 20, color: Colors.purple),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '拍完编辑',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '拍照后立即进入编辑模式',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _editAfterCapture,
                        onChanged: (v) =>
                            setState(() => _editAfterCapture = v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onChoice(CameraChoice choice) {
    Navigator.of(context).pop(CameraChoiceResult(
      choice: choice,
      folder: _selectedFolder,
      editAfterCapture: _editAfterCapture,
    ));
  }
}

/// 文件页面风格的选项卡片（使用列表样式代替原来的圆形图标卡片）
class _FileStyleChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FileStyleChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 文件页面风格图标容器
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
