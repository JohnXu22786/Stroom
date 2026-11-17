import 'dart:io';

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
  } catch (_) {
    await deleteAudioPlayerTempFile(file);
    rethrow;
  }

  if (isDisposed()) {
    await deleteAudioPlayerTempFile(file);
    return null;
  }
  return file;
}

Future<void> deleteAudioPlayerTempFile(File file) async {
  try {
    await file.delete();
  } on FileSystemException {
    // The file may already have been removed by dispose or a failed write.
  }
}
