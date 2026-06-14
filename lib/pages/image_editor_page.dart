import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

// ====================================================================
// Public types
// ====================================================================

/// Result returned by the image editor.
///
/// [editedBytes] contains the edited image bytes.
/// [isSaveAs] is `true` when the user chose "另存为" (save as new copy),
/// and `false` when the user chose "覆盖" (overwrite original).
class ImageEditorResult {
  final Uint8List editedBytes;
  final bool isSaveAs;

  const ImageEditorResult({
    required this.editedBytes,
    required this.isSaveAs,
  });
}

/// Actions for the save dialog.
///
/// Public for testability.
enum SaveAction { overwrite, saveAs, cancel }

/// Shows the save-as/overwrite dialog and returns the user's choice.
///
/// Extracted as a standalone function for testability.
Future<SaveAction?> showImageSaveDialog(BuildContext context) {
  return showDialog<SaveAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        '保存图片',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        '请选择保存方式：',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, SaveAction.cancel),
          child: const Text(
            '取消',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, SaveAction.overwrite),
          child: const Text(
            '覆盖',
            style: TextStyle(color: Colors.blue),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, SaveAction.saveAs),
          child: const Text('另存为'),
        ),
      ],
    ),
  );
}

// ====================================================================
// ImageEditorPage
// ====================================================================

/// Image editor page powered by [ProImageEditor].
///
/// Takes [imageBytes] as input, applies edits, and pops with an
/// [ImageEditorResult] (or pops with `null` if cancelled).
class ImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageEditorPage({super.key, required this.imageBytes});

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  /// Holds the edited image bytes after editing is complete.
  Uint8List? _editedBytes;

  /// Called when the user completes editing inside [ProImageEditor].
  Future<void> _onImageEditingComplete(Uint8List bytes) async {
    _editedBytes = bytes;
  }

  /// Called when the editor is about to close.
  void _onCloseEditor(EditorMode editorMode) {
    // Only handle closing of the main editor, not sub-editors.
    if (editorMode != EditorMode.main) return;

    if (_editedBytes != null) {
      // Editing completed — show the save dialog.
      _showSaveDialog();
    } else {
      // User cancelled — pop with null.
      Navigator.pop(context, null);
    }
  }

  /// Shows the save dialog and pops the page with the user's choice.
  Future<void> _showSaveDialog() async {
    if (!mounted) return;

    final result = await showImageSaveDialog(context);

    if (!mounted) return;

    if (result == null || result == SaveAction.cancel) {
      // User cancelled the save dialog — return to editor.
      _editedBytes = null;
      return;
    }

    final bytes = _editedBytes;
    if (bytes == null) return;

    Navigator.pop(
      context,
      ImageEditorResult(
        editedBytes: bytes,
        isSaveAs: result == SaveAction.saveAs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.memory(
      widget.imageBytes,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: _onImageEditingComplete,
        onCloseEditor: _onCloseEditor,
      ),
      configs: const ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
      ),
    );
  }
}
