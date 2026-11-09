import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_operation_rollback.dart';

class _Record {
  const _Record(this.id, this.folder);

  final String id;
  final String folder;
}

void main() {
  test('restores moved records and folders after a later operation fails',
      () async {
    final recordsById = <String, _Record>{
      'root': const _Record('root', 'old'),
      'child': const _Record('child', 'old/sub'),
      'unrelated': const _Record('unrelated', 'outside'),
    };
    final folders = <String>{'old', 'old/sub', 'outside'};
    final originalRecords = List<_Record>.unmodifiable(
      recordsById.values.where((record) => record.folder.startsWith('old')),
    );
    final originalFolders = Set<String>.of(folders);

    Future<List<_Record>> loadRecords() async => recordsById.values.toList();
    Future<Set<String>> getFolders() async => Set<String>.of(folders);
    Future<void> moveRecord(String id, String folder) async {
      recordsById[id] = _Record(id, folder);
    }

    Future<void> addFolder(String folder) async {
      folders.add(folder);
    }

    Future<void> removeFolder(String folder) async {
      final prefix = '$folder/';
      folders.removeWhere((path) => path == folder || path.startsWith(prefix));
    }

    await expectLater(
      runFolderOperationWithRollback<_Record>(
        originalRecords: originalRecords,
        originalFolders: originalFolders,
        rollbackFolderSubtrees: {'old', 'new'},
        createdFolderPaths: {'new', 'new/sub'},
        recordId: (record) => record.id,
        recordFolder: (record) => record.folder,
        loadRecords: loadRecords,
        getFolders: getFolders,
        moveRecordIfFolder: (
          id,
          expectedFolder,
          folder, {
          onMoved,
        }) async {
          if (recordsById[id]?.folder != expectedFolder) return false;
          await moveRecord(id, folder);
          onMoved?.call();
          return true;
        },
        addFolder: addFolder,
        removeFolder: removeFolder,
        operation: (moveOperationRecord) async {
          await moveOperationRecord('root', 'old', 'new');
          folders.addAll({'new', 'new/sub'});
          await moveOperationRecord('child', 'old/sub', 'new/sub');
          folders
              .removeWhere((path) => path == 'old' || path.startsWith('old/'));
          await moveRecord('unrelated', 'outside/newer');
          folders.add('outside/newer');
          folders.add('new/external_empty');
          throw StateError('injected failure after partial folder mutation');
        },
      ),
      throwsStateError,
    );

    expect(recordsById['root']?.folder, 'old');
    expect(recordsById['child']?.folder, 'old/sub');
    expect(recordsById['unrelated']?.folder, 'outside/newer');
    expect(folders, containsAll(originalFolders));
    expect(folders, contains('outside/newer'));
    expect(folders, contains('new/external_empty'));
  });

  test('preserves a record independently moved before rollback', () async {
    final recordsById = <String, _Record>{
      'root': const _Record('root', 'old'),
      'child': const _Record('child', 'old/sub'),
    };
    final folders = <String>{'old', 'old/sub'};
    final operationPaused = Completer<void>();
    final resumeOperation = Completer<void>();
    final originalRecords = List<_Record>.unmodifiable(recordsById.values);

    Future<List<_Record>> loadRecords() async => recordsById.values.toList();
    Future<Set<String>> getFolders() async => Set<String>.of(folders);
    Future<void> moveRecord(String id, String folder) async {
      recordsById[id] = _Record(id, folder);
    }

    final operation = runFolderOperationWithRollback<_Record>(
      originalRecords: originalRecords,
      originalFolders: Set<String>.of(folders),
      rollbackFolderSubtrees: {'old', 'new'},
      createdFolderPaths: {'new', 'new/sub'},
      recordId: (record) => record.id,
      recordFolder: (record) => record.folder,
      loadRecords: loadRecords,
      getFolders: getFolders,
      moveRecordIfFolder: (
        id,
        expectedFolder,
        folder, {
        onMoved,
      }) async {
        if (recordsById[id]?.folder != expectedFolder) return false;
        await moveRecord(id, folder);
        onMoved?.call();
        return true;
      },
      addFolder: (folder) async => folders.add(folder),
      removeFolder: (folder) async => folders.remove(folder),
      operation: (moveOperationRecord) async {
        await moveOperationRecord('root', 'old', 'new');
        folders.addAll({'new', 'new/sub'});
        operationPaused.complete();
        await resumeOperation.future;
        throw StateError('injected failure after independent move');
      },
    );

    await operationPaused.future;
    await moveRecord('root', 'new/sub');
    resumeOperation.complete();
    await expectLater(operation, throwsStateError);

    expect(recordsById['root']?.folder, 'new/sub');
    expect(recordsById['child']?.folder, 'old/sub');
    expect(folders, contains('new/sub'));
  });

  test('does not move a record changed after the operation snapshot', () async {
    final recordsById = <String, _Record>{
      'root': const _Record('root', 'old'),
      'child': const _Record('child', 'old/sub'),
    };
    final folders = <String>{'old', 'old/sub'};
    final operationPaused = Completer<void>();
    final resumeOperation = Completer<void>();
    final originalRecords = List<_Record>.unmodifiable(recordsById.values);

    Future<List<_Record>> loadRecords() async => recordsById.values.toList();
    Future<Set<String>> getFolders() async => Set<String>.of(folders);
    Future<void> moveRecord(String id, String folder) async {
      recordsById[id] = _Record(id, folder);
    }

    final operation = runFolderOperationWithRollback<_Record>(
      originalRecords: originalRecords,
      originalFolders: Set<String>.of(folders),
      rollbackFolderSubtrees: {'old', 'new'},
      createdFolderPaths: {'new', 'new/sub'},
      recordId: (record) => record.id,
      recordFolder: (record) => record.folder,
      loadRecords: loadRecords,
      getFolders: getFolders,
      moveRecordIfFolder: (
        id,
        expectedFolder,
        folder, {
        onMoved,
      }) async {
        if (recordsById[id]?.folder != expectedFolder) return false;
        await moveRecord(id, folder);
        onMoved?.call();
        return true;
      },
      addFolder: (folder) async => folders.add(folder),
      removeFolder: (folder) async => folders.remove(folder),
      operation: (moveOperationRecord) async {
        await moveOperationRecord('root', 'old', 'new');
        folders.add('new');
        operationPaused.complete();
        await resumeOperation.future;
        await moveOperationRecord('child', 'old/sub', 'new/sub');
        throw StateError('injected failure after concurrent move');
      },
    );

    await operationPaused.future;
    await moveRecord('child', 'outside/newer');
    folders.add('outside/newer');
    resumeOperation.complete();
    await expectLater(operation, throwsStateError);

    expect(recordsById['root']?.folder, 'old');
    expect(recordsById['child']?.folder, 'outside/newer');
    expect(folders, contains('outside/newer'));
  });

  test('conditionally restores owned records if the rollback read fails',
      () async {
    final recordsById = <String, _Record>{
      'root': const _Record('root', 'old'),
    };
    final folders = <String>{'old'};
    var failNextLoad = false;

    Future<List<_Record>> loadRecords() async {
      if (failNextLoad) {
        failNextLoad = false;
        throw StateError('injected read failure');
      }
      return recordsById.values.toList();
    }

    Future<void> moveRecord(String id, String folder) async {
      recordsById[id] = _Record(id, folder);
    }

    await expectLater(
      runFolderOperationWithRollback<_Record>(
        originalRecords: List<_Record>.unmodifiable(recordsById.values),
        originalFolders: Set<String>.of(folders),
        rollbackFolderSubtrees: {'old', 'new'},
        createdFolderPaths: {'new'},
        recordId: (record) => record.id,
        recordFolder: (record) => record.folder,
        loadRecords: loadRecords,
        getFolders: () async => Set<String>.of(folders),
        moveRecordIfFolder: (
          id,
          expectedFolder,
          folder, {
          onMoved,
        }) async {
          if (recordsById[id]?.folder != expectedFolder) return false;
          await moveRecord(id, folder);
          onMoved?.call();
          return true;
        },
        addFolder: (folder) async => folders.add(folder),
        removeFolder: (folder) async => folders.remove(folder),
        operation: (moveOperationRecord) async {
          await moveOperationRecord('root', 'old', 'new');
          folders.add('new');
          failNextLoad = true;
          throw StateError('injected operation failure');
        },
      ),
      throwsStateError,
    );

    expect(recordsById['root']?.folder, 'old');
    expect(folders, contains('new'));
  });
}
