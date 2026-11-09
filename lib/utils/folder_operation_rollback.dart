/// Runs a folder rename/move and restores its manifest snapshot if any step
/// fails. Record moves and folder-cache writes are persisted separately, so
/// they must be compensated in reverse after a partial failure.
Set<String> folderOperationDestinationPaths<T>({
  required String sourceFolder,
  required String destinationFolder,
  required Iterable<String> originalFolders,
  required Iterable<T> originalRecords,
  required String Function(T) recordFolder,
}) {
  final paths = <String>{destinationFolder};
  void addMappedPath(String path) {
    if (path == sourceFolder) {
      paths.add(destinationFolder);
    } else if (path.startsWith('$sourceFolder/')) {
      paths.add('$destinationFolder${path.substring(sourceFolder.length)}');
    }
  }

  for (final path in originalFolders) {
    addMappedPath(path);
  }
  for (final record in originalRecords) {
    addMappedPath(recordFolder(record));
  }
  return paths;
}

Future<void> runFolderOperationWithRollback<T>({
  /// Snapshot only the record rows this operation can mutate.
  required List<T> originalRecords,
  required Set<String> originalFolders,
  required Set<String> rollbackFolderSubtrees,
  Set<String> rollbackFolderPaths = const <String>{},
  required Set<String> createdFolderPaths,
  Set<String> rollbackRecordIds = const <String>{},
  required String Function(T) recordId,
  required String Function(T) recordFolder,
  required Future<List<T>> Function() loadRecords,
  required Future<Set<String>> Function() getFolders,
  required Future<void> Function(String id, String folder) moveRecord,
  required Future<void> Function(String folder) addFolder,
  required Future<void> Function(String folder) removeFolder,
  Future<void> Function(List<String> ids)? deleteRecords,
  required Future<void> Function() operation,
}) async {
  try {
    await operation();
  } catch (error, stackTrace) {
    bool isInRollbackScope(String folder) {
      if (rollbackFolderPaths.contains(folder)) return true;
      return rollbackFolderSubtrees.any(
        (scope) => folder == scope || folder.startsWith('$scope/'),
      );
    }

    Set<String>? currentFolderSnapshot;
    List<T>? currentRecords;
    try {
      currentRecords = await loadRecords();
    } catch (_) {
      // Fall back to restoring every original record if reading the current
      // manifest fails.
    }
    final currentFoldersById = {
      for (final record in currentRecords ?? <T>[])
        recordId(record): recordFolder(record),
    };
    final originalRecordIds = originalRecords.map(recordId).toSet();
    if (deleteRecords != null && rollbackRecordIds.isNotEmpty) {
      try {
        await deleteRecords(rollbackRecordIds.toList());
        currentRecords = await loadRecords();
      } catch (_) {
        // Continue cleaning folder metadata even when record deletion fails.
      }
    }
    var addedFolders = <String>{};
    try {
      currentFolderSnapshot = await getFolders();
      addedFolders = currentFolderSnapshot
          .difference(originalFolders)
          .where(createdFolderPaths.contains)
          .toSet();
    } catch (_) {
      // Continue restoring records even when reading folder metadata fails.
    }
    final foldersToRemove = addedFolders.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final folder in foldersToRemove) {
      final hasUnrelatedFolders = currentFolderSnapshot?.any(
            (path) =>
                path.startsWith('$folder/') &&
                !originalFolders.contains(path) &&
                !createdFolderPaths.contains(path),
          ) ??
          true;
      final hasUnrelatedRecords = currentRecords?.any((record) {
            final recordPath = recordFolder(record);
            return !originalRecordIds.contains(recordId(record)) &&
                (recordPath == folder || recordPath.startsWith('$folder/'));
          }) ??
          true;
      if (hasUnrelatedFolders || hasUnrelatedRecords) continue;
      try {
        await removeFolder(folder);
      } catch (_) {
        // Continue restoring the other pieces of the snapshot.
      }
    }
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
    for (final folder in originalFolders.where(isInRollbackScope)) {
      try {
        await addFolder(folder);
      } catch (_) {
        // Continue restoring the remaining folder metadata.
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
