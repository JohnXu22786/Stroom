import 'package:flutter/material.dart';

/// Three-state editor mode for the chart page.
enum EditorMode {
  /// 纯编辑 — only code editor visible
  edit,

  /// 一边编辑一边预览 — preview on top, code on bottom
  split,

  /// 纯预览 — only preview visible (with gesture zoom)
  preview;

  String get label {
    switch (this) {
      case EditorMode.edit:
        return '编辑模式';
      case EditorMode.split:
        return '编辑+预览';
      case EditorMode.preview:
        return '预览模式';
    }
  }

  IconData get icon {
    switch (this) {
      case EditorMode.edit:
        return Icons.code;
      case EditorMode.split:
        return Icons.view_column;
      case EditorMode.preview:
        return Icons.visibility;
    }
  }
}
