import 'dart:typed_data';

typedef StorageFileWriter = Future<String?> Function(
  String fileName,
  Uint8List bytes,
);
typedef StorageFileReader = Future<Uint8List?> Function(String fileName);
typedef StorageFileExistenceChecker = Future<bool> Function(String fileName);
typedef StorageFileDeleter = Future<void> Function(String fileName);

/// Runs a storage write and manifest publication as one recoverable operation.
///
/// If any write or publication step fails, newly created destinations are
/// removed when the manifest confirms that nothing references them. Previous
/// contents are restored, and files are kept when a failed manifest read makes
/// their reference status uncertain.
Future<T> publishStorageFiles<T, R>({
  required Future<T> Function(StorageFileWriter writeFile) publish,
  required Future<List<R>> Function() loadRecords,
  required bool Function(R record, String fileName) isReferenced,
  required StorageFileWriter writeFile,
  required StorageFileReader readFile,
  required StorageFileExistenceChecker fileExists,
  required StorageFileDeleter deleteFile,
}) async {
  final previousContents = <String, Uint8List?>{};
  final attemptedWrites = <String>{};

  Future<String?> writeTracked(String fileName, Uint8List bytes) async {
    if (!previousContents.containsKey(fileName)) {
      final existed = await fileExists(fileName);
      final previous = existed ? await readFile(fileName) : null;
      if (existed && previous == null) {
        throw StateError('Could not read existing storage file: $fileName');
      }
      previousContents[fileName] = previous;
    }
    attemptedWrites.add(fileName);
    return writeFile(fileName, bytes);
  }

  try {
    return await publish(writeTracked);
  } catch (error, stackTrace) {
    late final List<R> records;
    try {
      records = await loadRecords();
    } catch (_) {
      // Restore bytes that were already present, but keep newly created files
      // because a record may have been published before the read failed.
      for (final fileName in attemptedWrites) {
        final previous = previousContents[fileName];
        if (previous == null) continue;
        try {
          await writeFile(fileName, previous);
        } catch (_) {
          // Preserve the original write/publication error.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    for (final fileName in attemptedWrites) {
      final referenced = records.any(
        (record) => isReferenced(record, fileName),
      );
      final previous = previousContents[fileName];
      try {
        if (previous != null) {
          await writeFile(fileName, previous);
        } else if (!referenced) {
          await deleteFile(fileName);
        }
      } catch (_) {
        // Preserve the original write/publication error.
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
