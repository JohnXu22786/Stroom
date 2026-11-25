import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Keeps externally opened attachment copies available while the OS viewer
/// starts and reads them before removing the temporary copy.
const externalAttachmentPreviewGracePeriod = Duration(hours: 1);

/// Maximum time cleanup waits for a local media preview to initialize before
/// starting a bounded player-disposal wait and releasing the temporary file.
const attachmentPreviewInitializationWaitLimit = Duration(minutes: 1);

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
  Future<void> Function() disposePlayer, {
  bool Function()? shouldDisposePlayer,
  Future<void>? initialization,
  Duration initializationWaitLimit = attachmentPreviewInitializationWaitLimit,
}) async {
  var disposePlayerAfterInitialization = shouldDisposePlayer?.call() ?? true;
  var initializationWaitTimedOut = false;
  if (!disposePlayerAfterInitialization && initialization != null) {
    try {
      await initialization.timeout(
        initializationWaitLimit,
        onTimeout: () => initializationWaitTimedOut = true,
      );
    } catch (_) {
      // Failed or stuck initialization can leave video_player's creation
      // completer unresolved. Recheck for a player before releasing the file.
    }
    disposePlayerAfterInitialization = shouldDisposePlayer?.call() ?? true;
  }

  if (initializationWaitTimedOut && !disposePlayerAfterInitialization) {
    // Start disposal while cleanup still has the file. video_player's dispose
    // waits on its creation completer, so a player created shortly after the
    // initialization bound is released before the file is deleted.
    final disposal = _disposePreviewPlayer(disposePlayer);
    // Disposal may itself wait for the plugin's creation completer. Bound that
    // wait too; if a player appears during it, the full disposal still wins.
    await disposal.timeout(
      initializationWaitLimit,
      onTimeout: () {},
    );
    if (shouldDisposePlayer?.call() ?? true) {
      // A real player exists, so preserve the disposal-before-deletion rule.
      // If its disposal is still pending, let that operation finish.
      await disposal;
    } else {
      // No player exists. Delete without yielding so a late creation event
      // cannot slip between this final check and file removal. If disposal
      // timed out, its in-flight future can still release a later-created one.
      _deleteAttachmentPreviewFileSynchronously(filePath);
      return;
    }
  }

  if (disposePlayerAfterInitialization) {
    await _disposePreviewPlayer(disposePlayer);
  }
  await deleteAttachmentPreviewFile(filePath);
}

Future<void> _disposePreviewPlayer(
  Future<void> Function() disposePlayer,
) async {
  try {
    await disposePlayer();
  } catch (e) {
    debugPrint('[AttachmentPreview] player disposal failed: $e');
  }
}

void _deleteAttachmentPreviewFileSynchronously(String filePath) {
  try {
    final file = File(filePath);
    if (file.existsSync()) file.deleteSync();
  } catch (e) {
    debugPrint('[AttachmentPreview] temp file cleanup failed: $e');
  }
}

/// Ensures concurrent lifecycle paths share one controller-disposal operation.
class AttachmentPreviewFileLifecycle {
  AttachmentPreviewFileLifecycle(this.filePath);

  final String filePath;
  Future<void>? _cleanup;

  Future<void> disposePlayerAndDelete(
    Future<void> Function() disposePlayer, {
    bool Function()? shouldDisposePlayer,
    Future<void>? initialization,
    Duration initializationWaitLimit = attachmentPreviewInitializationWaitLimit,
  }) {
    return _cleanup ??= disposePreviewPlayerAndDeleteFile(
      filePath,
      disposePlayer,
      shouldDisposePlayer: shouldDisposePlayer,
      initialization: initialization,
      initializationWaitLimit: initializationWaitLimit,
    );
  }
}
