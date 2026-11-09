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
      for (final entry in recordsById.entries.toList()) {
        if (entry.value.folder == folder ||
            entry.value.folder.startsWith(prefix)) {
          recordsById[entry.key] = _Record(entry.key, '');
        }
      }
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
        moveRecord: moveRecord,
        addFolder: addFolder,
        removeFolder: removeFolder,
        operation: () async {
          await moveRecord('root', 'new');
          folders.addAll({'new', 'new/sub'});
          await moveRecord('child', 'new/sub');
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
}
