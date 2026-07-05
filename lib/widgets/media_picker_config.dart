import 'dart:typed_data';

import 'package:flutter/material.dart';

// ============================================================================
// MediaPickerConfig — configuration for the unified media picker
// ============================================================================

/// Configuration for the unified media picker dialog.
///
/// [T] is the record type (e.g., [AudioRecord], [VideoRecord], [ImageRecord]).
class MediaPickerConfig<T> {
  /// Dialog title (e.g., '选择应用内录音', '选择应用内视频').
  final String title;

  /// Icon shown in the empty state.
  final IconData emptyIcon;

  /// Text shown when there are no records (e.g., '暂无录音', '暂无视频').
  final String emptyText;

  /// Icon shown for each file item.
  final IconData fileIcon;

  /// Color tint for the file icon.
  final Color? fileIconColor;

  /// Whether multi-select mode is enabled.
  ///
  /// In single-select mode (default), tapping an item immediately selects it
  /// and closes the dialog. In multi-select mode, checkboxes and a preview
  /// bar are shown, and the user must tap a confirm button.
  final bool multiSelect;

  /// Loads all records for display.
  final Future<List<T>> Function() loadRecords;

  /// Loads all folder paths for navigation.
  final Future<Set<String>> Function() loadFolders;

  /// Reads the raw bytes of a given record.
  final Future<Uint8List?> Function(T record) readFile;

  /// Returns the display name for a record (shown as the primary text).
  final String Function(T record) displayName;

  /// Builds the subtitle widget shown below the display name.
  ///
  /// Typically shows format, size, duration, etc.
  final Widget Function(T record) subtitleBuilder;

  const MediaPickerConfig({
    required this.title,
    required this.emptyIcon,
    required this.emptyText,
    required this.fileIcon,
    this.fileIconColor,
    this.multiSelect = false,
    required this.loadRecords,
    required this.loadFolders,
    required this.readFile,
    required this.displayName,
    required this.subtitleBuilder,
  });
}
