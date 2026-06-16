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
  });

  static List<PopupMenuEntry<String>> _defaultExtraMenu(_) => [];
}
