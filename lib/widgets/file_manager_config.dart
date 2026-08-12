import 'package:flutter/material.dart';

import '../utils/file_record.dart';

/// Per-page customization for [FileManagerView].
class FileManagerConfig<T extends FileRecord> {
  final String title;
  final Widget? topActionBar;
  final bool showThumbnailToggle;
  final bool initialGridView;
  final void Function(bool)? onGridViewChanged;
  final Widget Function(T) fileIconBuilder;
  final Widget Function(T)? fileThumbnailBuilder;
  final void Function(T) onFileTap;
  final List<PopupMenuEntry<String>> Function(T) extraPopupMenuItems;
  final void Function(T, String)? onExtraMenuAction;
  final void Function(T)? onLongPress;
  final void Function(String)? onCurrentFolderChanged;
  final List<Widget> Function()? extraAppBarActions;

  /// 重命名对话框中可选的文件格式列表。当文件的 [FileRecord.format]
  /// 包含在此列表中时，重命名对话框会显示格式下拉框（与创建页一致），
  /// 让用户在这几种格式之间切换；否则保持纯文本改名。
  final List<String>? renameFormatOptions;

  const FileManagerConfig({
    required this.title,
    this.topActionBar,
    this.showThumbnailToggle = false,
    this.initialGridView = false,
    this.onGridViewChanged,
    required this.fileIconBuilder,
    this.fileThumbnailBuilder,
    required this.onFileTap,
    this.extraPopupMenuItems = _defaultExtraMenu,
    this.onExtraMenuAction,
    this.onLongPress,
    this.onCurrentFolderChanged,
    this.extraAppBarActions,
    this.renameFormatOptions,
  });

  static List<PopupMenuEntry<String>> _defaultExtraMenu(Object? _) => [];
}
