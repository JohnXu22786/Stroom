import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Writes a native audio temp file unless its owner has been disposed.
///
/// The disposal check after the write handles the case where disposal happens
/// while the filesystem write is in progress and its completion recreates the
/// file after the owner's initial cleanup attempt.
Future<File?> writeAudioPlayerTempFile({
  required List<int> bytes,
  required String extension,
  required bool Function() isDisposed,
  Future<Directory> Function()? getTempDirectory,
  Future<void> Function(File file, List<int> bytes)? writeBytes,
  DateTime Function()? now,
}) async {
  final directory = await (getTempDirectory ?? getTemporaryDirectory)();
  if (isDisposed()) return null;

  final file = File(
    '${directory.path}/${(now ?? DateTime.now)().millisecondsSinceEpoch}_${const Uuid().v4()}.$extension',
  );
  try {
    await (writeBytes ?? (file, bytes) => file.writeAsBytes(bytes))(
      file,
      bytes,
    );
  } catch (writeError) {
    try {
      await deleteAudioPlayerTempFile(file);
    } catch (cleanupError) {
      debugPrint(
        'Failed to remove partial audio file ${file.path} after write error '
        '($writeError): $cleanupError',
      );
    }
    rethrow;
  }

  if (isDisposed()) {
    try {
      await deleteAudioPlayerTempFile(file);
    } catch (cleanupError) {
      debugPrint(
        'Failed to remove disposed audio temp file ${file.path}: $cleanupError',
      );
      rethrow;
    }
    return null;
  }
  return file;
}

Future<void> deleteAudioPlayerTempFile(File file) async {
  try {
    await file.delete();
  } on FileSystemException catch (error) {
    // The file may already have been removed by dispose or a failed write.
    final errorCode = error.osError?.errorCode;
    if (errorCode == 2 || errorCode == 3) return;
    rethrow;
  }
}

Future<void> disposeAudioPlayerTempFile({
  required Future<void> Function() disposePlayer,
  required String? tempFilePath,
}) async {
  try {
    await disposePlayer();
  } catch (disposeError, stackTrace) {
    if (tempFilePath != null) {
      try {
        await deleteAudioPlayerTempFile(File(tempFilePath));
      } catch (cleanupError) {
        debugPrint(
          'Failed to remove audio temp file $tempFilePath after player '
          'disposal error ($disposeError): $cleanupError',
        );
      }
    }
    Error.throwWithStackTrace(disposeError, stackTrace);
  }
  if (tempFilePath != null) {
    await deleteAudioPlayerTempFile(File(tempFilePath));
  }
}
