import 'dart:io';

import 'package:flutter/material.dart';

/// Keeps externally opened attachment copies available while the OS viewer
/// starts and reads them before removing the temporary copy.
const externalAttachmentPreviewGracePeriod = Duration(hours: 1);

/// Shows a media preview dialog and removes its temporary copy if route
/// creation fails. A successful preview owns cleanup after player disposal.
Future<T?> showAttachmentPreviewDialog<T>({
  required BuildContext context,
  required String filePath,
  required WidgetBuilder builder,
}) async {
  try {
    return await showDialog<T>(context: context, builder: builder);
  } catch (_) {
    await deleteAttachmentPreviewFile(filePath);
    rethrow;
  }
}

/// Removes a temporary attachment preview file if it still exists.
Future<void> deleteAttachmentPreviewFile(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  } catch (e) {
    debugPrint('[AttachmentPreview] temp file cleanup failed: $e');
  }
}

/// Removes an externally opened preview after its viewer has had time to read
/// the file. The OS does not report when an external viewer is finished.
Future<void> deleteAttachmentPreviewFileAfterDelay(
  String filePath, {
  Duration delay = externalAttachmentPreviewGracePeriod,
}) async {
  await Future<void>.delayed(delay);
  await deleteAttachmentPreviewFile(filePath);
}

/// Removes a partial preview copy when writing its contents fails.
Future<void> writeAttachmentPreviewFile(
  String filePath,
  Future<void> Function(File file) write,
) async {
  try {
    await write(File(filePath));
  } catch (_) {
    await deleteAttachmentPreviewFile(filePath);
    rethrow;
  }
}

/// Waits for the media controller to release its file before removing it.
Future<void> disposePreviewPlayerAndDeleteFile(
  String filePath,
  Future<void> Function() disposePlayer,
) async {
  try {
    await disposePlayer();
  } catch (e) {
    debugPrint('[AttachmentPreview] player disposal failed: $e');
  }
  await deleteAttachmentPreviewFile(filePath);
}

/// Ensures concurrent lifecycle paths share one controller-disposal operation.
class AttachmentPreviewFileLifecycle {
  AttachmentPreviewFileLifecycle(this.filePath);

  final String filePath;
  Future<void>? _cleanup;

  Future<void> disposePlayerAndDelete(Future<void> Function() disposePlayer) {
    return _cleanup ??= disposePreviewPlayerAndDeleteFile(
      filePath,
      disposePlayer,
    );
  }
}
