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

/// Actions for save/discard dialogs.
///
/// Public for testability.
enum SaveAction {
  overwrite,
  saveAs,
  cancel,
  /// Save the original photo (camera flow, no edits made).
  save,
  /// Discard the original photo (camera flow).
  discard,
}

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

/// Shows a save-or-discard dialog for photos taken from camera.
///
/// This is shown when the user presses X in the main editor without having
/// made any edits, and the photo came from the camera (not gallery).
///
/// Returns [SaveAction.save] to keep the original photo,
/// [SaveAction.discard] to discard it, or [SaveAction.cancel] to return
/// to the editor.
Future<SaveAction?> showDiscardOrSaveDialog(BuildContext context) {
  return showDialog<SaveAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        '保存照片',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        '是否保存当前照片？',
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
          onPressed: () => Navigator.pop(ctx, SaveAction.discard),
          child: const Text(
            '不保存',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, SaveAction.save),
          child: const Text('保存'),
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
///
/// When [fromCamera] is `true`, pressing X without editing will prompt
/// the user to save or discard the original photo instead of silently
/// discarding it.
class ImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final bool fromCamera;

  const ImageEditorPage({
    super.key,
    required this.imageBytes,
    this.fromCamera = false,
  });

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
  ///
  /// For sub-editor modes (blur, crop, etc.), we let the sub-editor close
  /// by popping from the Navigator (the sub-editor is pushed as a route
  /// on the same Navigator when [enableSubEditorPage] is false).
  ///
  /// For the main editor mode:
  /// - If edits were made, show the save dialog.
  /// - If no edits were made and the photo came from camera, show a
  ///   save-or-discard dialog to avoid losing the captured photo.
  /// - Otherwise (no edits, gallery source), pop with `null`.
  void _onCloseEditor(EditorMode editorMode) {
    // Sub-editor modes — pop the sub-editor route from the Navigator.
    if (editorMode != EditorMode.main) {
      Navigator.pop(context);
      return;
    }

    if (_editedBytes != null) {
      // Editing completed — show the save dialog.
      _showSaveDialog();
    } else if (widget.fromCamera) {
      // Came from camera with no edits — ask whether to save the original.
      _showDiscardOrSaveDialog();
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

  /// Shows the save-or-discard dialog for camera-originated photos.
  Future<void> _showDiscardOrSaveDialog() async {
    if (!mounted) return;

    final result = await showDiscardOrSaveDialog(context);

    if (!mounted) return;

    if (result == null || result == SaveAction.cancel) {
      // User cancelled — return to editor.
      return;
    }

    if (result == SaveAction.save) {
      // Save the original (unedited) photo.
      Navigator.pop(
        context,
        ImageEditorResult(
          editedBytes: widget.imageBytes,
          isSaveAs: false,
        ),
      );
    } else {
      // Discard — pop with null.
      Navigator.pop(context, null);
    }
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
