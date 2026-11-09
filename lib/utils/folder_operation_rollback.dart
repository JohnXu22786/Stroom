/// Runs a folder rename/move and restores its manifest snapshot if any step
/// fails. Record moves and folder-cache writes are persisted separately, so
/// they must be compensated in reverse after a partial failure.
Future<void> runFolderOperationWithRollback<T>({
  required List<T> originalRecords,
  required Set<String> originalFolders,
  required String Function(T) recordId,
  required String Function(T) recordFolder,
  required Future<List<T>> Function() loadRecords,
  required Future<Set<String>> Function() getFolders,
  required Future<void> Function(String id, String folder) moveRecord,
  required Future<void> Function(String folder) addFolder,
  required Future<void> Function(String folder) removeFolder,
  required Future<void> Function() operation,
}) async {
  try {
    await operation();
  } catch (error, stackTrace) {
    var addedFolders = <String>{};
    try {
      addedFolders = (await getFolders()).difference(originalFolders);
    } catch (_) {
      // Continue restoring records even when reading folder metadata fails.
    }
    final addedRoots = addedFolders.where((folder) {
        var parent = folder.contains('/')
            ? folder.substring(0, folder.lastIndexOf('/'))
            : '';
        while (parent.isNotEmpty) {
          if (addedFolders.contains(parent)) return false;
          parent = parent.contains('/')
              ? parent.substring(0, parent.lastIndexOf('/'))
              : '';
        }
        return true;
      });
    for (final folder in addedRoots) {
      try {
        await removeFolder(folder);
      } catch (_) {
        // Continue restoring the other pieces of the snapshot.
      }
    }
    List<T>? currentRecords;
    try {
      currentRecords = await loadRecords();
    } catch (_) {
      // Fall back to restoring every original record if reading the current
      // manifest fails.
    }
    final currentFoldersById = {
      for (final record in currentRecords ?? <T>[]) recordId(record): recordFolder(record),
    };
    for (final record in originalRecords) {
      if (currentRecords != null &&
          currentFoldersById[recordId(record)] == recordFolder(record)) {
        continue;
      }
      try {
        await moveRecord(recordId(record), recordFolder(record));
      } catch (_) {
        // Continue restoring the other records even if one write fails.
      }
    }
    for (final folder in originalFolders) {
      try {
        await addFolder(folder);
      } catch (_) {
        // Continue restoring the remaining folder metadata.
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
