import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/manifest_operations.dart';
import 'package:stroom/services/text_storage_tool_service.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

Future<void> _writePersistedTextRecord(
  String id,
  Map<String, dynamic> updates,
) async {
  final raw = await WebFileStore.read('manifest_database_data');
  final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
  final records = data[ManifestTables.textRecords] as List<dynamic>;
  (records.singleWhere((record) => (record as Map)['id'] == id)
          as Map<String, dynamic>)
      .addAll(updates);
  await WebFileStore.write(
    'manifest_database_data',
    Uint8List.fromList(utf8.encode(jsonEncode(data))),
  );
}

Future<void> _addPersistedTextRecord(Map<String, dynamic> record) async {
  final raw = await WebFileStore.read('manifest_database_data');
  final data = jsonDecode(utf8.decode(raw!)) as Map<String, dynamic>;
  (data[ManifestTables.textRecords] as List<dynamic>).add(record);
  await WebFileStore.write(
    'manifest_database_data',
    Uint8List.fromList(utf8.encode(jsonEncode(data))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
  });

  tearDown(() async {
    await ManifestDatabase.clearAllData();
    TextManifest.invalidateCache();
  });

  test('creates, lists, searches, and reads a text-space document', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Lecture Notes',
        'content': 'Photosynthesis converts light into chemical energy.',
        'format': 'md',
        'folder': 'Biology/Week 1',
      }),
    ) as Map<String, dynamic>;

    expect(created['status'], 'created');
    expect(created['folder'], 'Biology/Week 1');

    final listed = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_list', {
        'folder': 'Biology',
      }),
    ) as Map<String, dynamic>;
    expect(listed['count'], 1);
    expect((listed['documents'] as List).single['id'], created['id']);

    final searched = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_search', {
        'query': 'chemical energy',
      }),
    ) as Map<String, dynamic>;
    expect(searched['count'], 1);
    expect(
      (searched['results'] as List).single['snippet'],
      contains('chemical energy'),
    );

    final read = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_read', {
        'record_id': created['id'],
      }),
    ) as Map<String, dynamic>;
    expect(
      read['content'],
      'Photosynthesis converts light into chemical energy.',
    );
    expect(read['complete'], isTrue);
    expect(read['hash'], isNotEmpty);
  });

  test(
    'normalizes a matching filename extension and rejects mismatches',
    () async {
      final normalized = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Lesson.md',
          'content': 'Notes',
          'format': 'md',
        }),
      ) as Map<String, dynamic>;
      expect(normalized['name'], 'Lesson');

      final mismatched = await TextStorageToolService.handleTool(
        'stroom_space_write',
        {'name': 'Lesson.md', 'content': 'Notes', 'format': 'txt'},
      );
      expect(mismatched, contains('name 不要包含扩展名'));
      expect((await TextManifest.loadRecords()).length, 1);
    },
  );

  test(
    'rejects unsafe folders and stale replacement without altering content',
    () async {
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Notes',
          'content': 'Original text',
        }),
      ) as Map<String, dynamic>;

      final unsafe = await TextStorageToolService.handleTool(
        'stroom_space_write',
        {'name': 'Escape', 'content': 'no', 'folder': '../outside'},
      );
      expect(unsafe, startsWith('错误:'));
      expect((await TextManifest.loadRecords()).length, 1);

      final stale =
          await TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': created['id'],
        'expected_hash': 'stale-hash',
        'expected_metadata_hash': created['metadata_hash'],
        'name': 'Notes',
        'content': 'Overwritten text',
      });
      expect(stale, startsWith('错误:'));

      final read = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_read', {
          'record_id': created['id'],
        }),
      ) as Map<String, dynamic>;
      expect(read['content'], 'Original text');
    },
  );

  test('rejects folder paths over the total length limit', () async {
    final folder = List.filled(11, 'a' * 100).join('/');

    final result = await TextStorageToolService.handleTool(
      'stroom_space_write',
      {'name': 'Too Deep', 'content': 'Notes', 'folder': folder},
    );

    expect(result, contains('folder 路径不能超过 1024 个字符'));
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  test('replaces a document only with its current hash', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Draft',
        'content': 'First version',
      }),
    ) as Map<String, dynamic>;

    final updated = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': created['id'],
        'expected_hash': created['hash'],
        'expected_metadata_hash': created['metadata_hash'],
        'name': 'Draft',
        'content': 'Second version',
      }),
    ) as Map<String, dynamic>;
    expect(updated['status'], 'updated');
    expect(updated['hash'], isNot(created['hash']));

    final read = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_read', {
        'record_id': created['id'],
      }),
    ) as Map<String, dynamic>;
    expect(read['content'], 'Second version');
  });

  test('preserves format and folder when omitted on replacement', () async {
    for (final format in ['txt', 'mmd']) {
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Class Notes',
          'content': 'Original text',
          'format': format,
          'folder': 'Biology/Week 1',
        }),
      ) as Map<String, dynamic>;

      final updated = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'record_id': created['id'],
          'expected_hash': created['hash'],
          'expected_metadata_hash': created['metadata_hash'],
          'name': 'Class Notes Updated.$format',
          'content': 'Updated text',
        }),
      ) as Map<String, dynamic>;

      expect(updated['name'], 'Class Notes Updated');
      expect(updated['format'], format);
      expect(updated['folder'], 'Biology/Week 1');
    }
  });

  test('rejects a stale text editor save after a tool replacement', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Shared Draft',
        'content': 'Original text',
        'format': 'txt',
        'folder': 'Class Notes',
      }),
    ) as Map<String, dynamic>;
    final originalRecord = (await TextManifest.loadRecords()).single;
    await TextStorageToolService.handleTool('stroom_space_write', {
      'record_id': created['id'],
      'expected_hash': created['hash'],
      'expected_metadata_hash': created['metadata_hash'],
      'name': 'Shared Draft',
      'content': 'Agent replacement',
    });

    const editorContent = 'Stale editor content';
    final editorBytes = Uint8List.fromList(utf8.encode(editorContent));
    final editorRecord = TextRecord(
      id: created['id'] as String,
      name: 'Shared Draft',
      hash: computeTextHash(editorBytes),
      format: 'txt',
      createdAt: originalRecord.createdAt,
      modifiedAt: DateTime.now(),
      size: editorBytes.length,
      folder: 'Class Notes',
      textLength: editorContent.length,
    );

    final saved = await TextManifest.updateRecordIfHashWithContent(
      created['id'] as String,
      created['hash'] as String,
      {'name': 'Shared Draft', 'format': 'txt', 'folder': 'Class Notes'},
      editorRecord,
      editorBytes,
    );

    expect(saved, isFalse);
    final read = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_read', {
        'record_id': created['id'],
      }),
    ) as Map<String, dynamic>;
    expect(read['content'], 'Agent replacement');
  });

  test(
    'reclaims replaced content only after its last record reference',
    () async {
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Shared Old Content',
          'content': 'Shared original',
        }),
      ) as Map<String, dynamic>;
      final duplicate = TextRecord(
        name: 'Old Content Copy',
        hash: created['hash'] as String,
        format: 'md',
        createdAt: DateTime.utc(2026),
        size: 'Shared original'.length,
        textLength: 'Shared original'.length,
      );
      await TextManifest.addRecord(duplicate);

      final updated = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'record_id': created['id'],
          'expected_hash': created['hash'],
          'expected_metadata_hash': created['metadata_hash'],
          'name': 'Shared Old Content',
          'content': 'Replacement content',
        }),
      ) as Map<String, dynamic>;

      expect(
        await TextManifest.readText('${created['hash']}.txt'),
        'Shared original',
      );
      await TextManifest.deleteRecord(duplicate.id);
      expect(await TextManifest.readFile('${created['hash']}.txt'), isNull);
      expect(
        await TextManifest.readText('${updated['hash']}.txt'),
        'Replacement content',
      );
    },
  );

  test(
    'cleans an unreferenced file after a rejected conditional update',
    () async {
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Conditional Target',
          'content': 'Current content',
        }),
      ) as Map<String, dynamic>;
      const rejectedContent = 'Rejected content';
      final rejectedBytes = Uint8List.fromList(utf8.encode(rejectedContent));
      final rejectedHash = computeTextHash(rejectedBytes);
      final updatedRecord = TextRecord(
        id: created['id'] as String,
        name: 'Conditional Target',
        hash: rejectedHash,
        format: 'md',
        createdAt: DateTime.utc(2026),
        size: rejectedBytes.length,
        textLength: rejectedContent.length,
      );

      final updated = await TextManifest.updateRecordIfHashWithContent(
        created['id'] as String,
        'stale-hash',
        {'name': 'Conditional Target', 'format': 'md', 'folder': ''},
        updatedRecord,
        rejectedBytes,
      );

      expect(updated, isFalse);
      expect(await TextManifest.readFile('$rejectedHash.txt'), isNull);
    },
  );

  test(
    'rejects adding a text record when its content file is missing',
    () async {
      const content = 'Missing file';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        name: 'Broken reference',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        textLength: content.length,
      );

      await expectLater(TextManifest.addRecord(record), throwsStateError);
      expect(await TextManifest.loadRecords(), isEmpty);
    },
  );

  test(
    'rejects content whose bytes do not match the record hash before write',
    () async {
      const originalContent = 'Content referenced by an existing record';
      final originalBytes = Uint8List.fromList(utf8.encode(originalContent));
      final original = TextRecord(
        id: 'hash-protected-original',
        name: 'Original',
        hash: computeTextHash(originalBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.writeFile(original.storageFileName, originalBytes);
      await TextManifest.addRecord(original);

      final mismatched = TextRecord(
        id: 'hash-mismatch',
        name: 'Mismatched',
        hash: original.hash,
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: 'Different body'.length,
      );
      expect(
        () => TextManifest.addRecordWithContent(
          mismatched,
          Uint8List.fromList(utf8.encode('Different body')),
        ),
        throwsArgumentError,
      );

      expect(
        await TextManifest.readText(original.storageFileName),
        originalContent,
      );
      expect((await TextManifest.loadRecords()).map((record) => record.id), [
        original.id,
      ]);
    },
  );

  test(
    'rejects mismatched conditional replacement bytes before writing',
    () async {
      const originalContent = 'Keep the existing referenced bytes';
      final originalBytes = Uint8List.fromList(utf8.encode(originalContent));
      final original = TextRecord(
        id: 'conditional-hash-protected-original',
        name: 'Original',
        hash: computeTextHash(originalBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.writeFile(original.storageFileName, originalBytes);
      await TextManifest.addRecord(original);

      final updatedBytes = Uint8List.fromList(utf8.encode('Replacement'));
      final updated = TextRecord(
        id: original.id,
        name: original.name,
        hash: original.hash,
        format: original.format,
        createdAt: original.createdAt,
        size: updatedBytes.length,
      );

      expect(
        () => TextManifest.updateRecordIfHashWithContent(
          original.id,
          original.hash,
          {'name': original.name, 'format': original.format, 'folder': ''},
          updated,
          updatedBytes,
        ),
        throwsArgumentError,
      );

      expect(
        await TextManifest.readText(original.storageFileName),
        originalContent,
      );
      expect((await TextManifest.loadRecords()).single.hash, original.hash);
    },
  );

  test('rejects a conditional update that changes the record id', () async {
    const content = 'Stable record identity';
    final bytes = Uint8List.fromList(utf8.encode(content));
    final original = TextRecord(
      id: 'stable-id',
      name: 'Original',
      hash: computeTextHash(bytes),
      format: 'txt',
      createdAt: DateTime.utc(2026),
      size: bytes.length,
    );
    await TextManifest.writeFile(original.storageFileName, bytes);
    await TextManifest.addRecord(original);

    final updated = TextRecord(
      id: 'different-id',
      name: 'Renamed',
      hash: original.hash,
      format: original.format,
      createdAt: original.createdAt,
      size: original.size,
    );

    await expectLater(
      TextManifest.updateRecordIfHash(
          original.id,
          original.hash,
          {
            'name': original.name,
            'format': original.format,
            'folder': '',
          },
          updated),
      throwsArgumentError,
    );

    expect((await TextManifest.loadRecords()).single.id, original.id);
  });

  test('rejects a replacement after the document metadata changes', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Original Name',
        'content': 'Original content',
        'folder': 'Class Notes',
      }),
    ) as Map<String, dynamic>;
    await TextManifest.renameRecord(created['id'] as String, 'Renamed');

    final result =
        await TextStorageToolService.handleTool('stroom_space_write', {
      'record_id': created['id'],
      'expected_hash': created['hash'],
      'expected_metadata_hash': created['metadata_hash'],
      'name': 'Original Name',
      'content': 'Agent replacement',
      'folder': 'Class Notes',
    });

    expect(result, contains('名称、格式或文件夹'));
    final read = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_read', {
        'record_id': created['id'],
      }),
    ) as Map<String, dynamic>;
    expect(read['content'], 'Original content');
    expect(read['name'], 'Renamed');
  });

  test(
    'allows only one of two concurrent replacements with the same hash',
    () async {
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Concurrent Draft',
          'content': 'Shared starting version',
        }),
      ) as Map<String, dynamic>;

      final results = await Future.wait([
        TextStorageToolService.handleTool('stroom_space_write', {
          'record_id': created['id'],
          'expected_hash': created['hash'],
          'expected_metadata_hash': created['metadata_hash'],
          'name': 'Concurrent Draft',
          'content': 'First replacement',
        }),
        TextStorageToolService.handleTool('stroom_space_write', {
          'record_id': created['id'],
          'expected_hash': created['hash'],
          'expected_metadata_hash': created['metadata_hash'],
          'name': 'Concurrent Draft',
          'content': 'Second replacement',
        }),
      ]);

      expect(results.where((result) => result.startsWith('错误:')).length, 1);
      expect(results.where((result) => result.startsWith('{')).length, 1);
      final read = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_read', {
          'record_id': created['id'],
        }),
      ) as Map<String, dynamic>;
      expect([
        'First replacement',
        'Second replacement',
      ], contains(read['content']));
      expect(await TextManifest.readFile('${created['hash']}.txt'), isNull);
    },
  );

  test(
    'serializes replacement content creation with deletion of its shared reference',
    () async {
      final shared = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Shared Copy',
          'content': 'New shared content',
        }),
      ) as Map<String, dynamic>;
      final target = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'To Replace',
          'content': 'Old content',
        }),
      ) as Map<String, dynamic>;

      final replacement =
          TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': target['id'],
        'expected_hash': target['hash'],
        'expected_metadata_hash': target['metadata_hash'],
        'name': 'To Replace',
        'content': 'New shared content',
      });
      final deletion = TextManifest.deleteRecord(shared['id'] as String);

      expect(await replacement, contains('"status":"updated"'));
      await deletion;
      final read = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_read', {
          'record_id': target['id'],
        }),
      ) as Map<String, dynamic>;
      expect(read['content'], 'New shared content');
      expect(
        await TextManifest.readText('${read['hash']}.txt'),
        'New shared content',
      );
    },
  );

  test('keeps a read snapshot available while a replacement waits', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Read race',
        'content': 'Snapshot body',
      }),
    ) as Map<String, dynamic>;
    final readStarted = Completer<void>();
    final releaseRead = Completer<void>();
    final pendingRead = TextManifest.withSerializedTextRead(() async {
      final record = (await TextManifest.loadRecords()).single;
      readStarted.complete();
      await releaseRead.future;
      return TextManifest.readText(record.storageFileName);
    });
    await readStarted.future;

    var replacementCompleted = false;
    final replacement =
        TextStorageToolService.handleTool('stroom_space_write', {
      'record_id': created['id'],
      'expected_hash': created['hash'],
      'expected_metadata_hash': created['metadata_hash'],
      'name': 'Read race',
      'content': 'Replacement body',
    }).then((result) {
      replacementCompleted = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(replacementCompleted, isFalse);

    releaseRead.complete();
    expect(await pendingRead, 'Snapshot body');
    await replacement;
    expect(replacementCompleted, isTrue);
  });

  test(
    'serializes text creation with removal of another shared-file reference',
    () async {
      const content = 'Shared copy content';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Folder Copy',
        'content': content,
        'folder': 'To Delete',
      });
      final copy = TextRecord(
        name: 'Root Copy',
        hash: hash,
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        textLength: content.length,
      );

      await Future.wait([
        TextManifest.addRecordWithContent(copy, bytes),
        TextManifest.removeFolder('To Delete'),
      ]);

      final stored = (await TextManifest.loadRecords()).single;
      expect(stored.id, copy.id);
      expect(await TextManifest.readText(stored.storageFileName), content);
    },
  );

  test(
    'serializes folder removal with replacement of a shared content file',
    () async {
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Folder Copy',
        'content': 'Shared replacement content',
        'folder': 'To Delete',
      });
      final target = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Root Document',
          'content': 'Original content',
        }),
      ) as Map<String, dynamic>;

      final replacement =
          TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': target['id'],
        'expected_hash': target['hash'],
        'expected_metadata_hash': target['metadata_hash'],
        'name': 'Root Document',
        'content': 'Shared replacement content',
      });
      final removal = TextManifest.removeFolder('To Delete');

      expect(await replacement, contains('"status":"updated"'));
      await removal;

      final read = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_read', {
          'record_id': target['id'],
        }),
      ) as Map<String, dynamic>;
      expect(read['content'], 'Shared replacement content');
      expect(
        await TextManifest.readText('${read['hash']}.txt'),
        'Shared replacement content',
      );
    },
  );

  test(
    'serializes moving folder contents to root with content replacement',
    () async {
      final target = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Folder Draft',
          'content': 'Original content',
          'folder': 'To Move',
        }),
      ) as Map<String, dynamic>;

      final replacement =
          TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': target['id'],
        'expected_hash': target['hash'],
        'expected_metadata_hash': target['metadata_hash'],
        'name': 'Folder Draft',
        'content': 'Replacement content',
      });
      final moveToRoot = TextManifest.removeFolderFromCache('To Move');
      await Future.wait([replacement, moveToRoot]);

      final record = (await TextManifest.loadRecords()).single;
      expect(record.folder, '');
      expect(await TextManifest.readText(record.storageFileName), isNotNull);
    },
  );

  test('format changes preserve a newer content replacement', () async {
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Format Draft',
        'content': 'Original content',
        'format': 'md',
        'folder': 'Class Notes',
      }),
    ) as Map<String, dynamic>;
    await TextStorageToolService.handleTool('stroom_space_write', {
      'record_id': created['id'],
      'expected_hash': created['hash'],
      'expected_metadata_hash': created['metadata_hash'],
      'name': 'Format Draft',
      'content': 'New content',
    });

    final changed = await TextManifest.renameRecordWithFormat(
      created['id'] as String,
      'Format Draft Updated',
      'txt',
    );

    expect(changed, isTrue);
    final record = (await TextManifest.loadRecords()).single;
    expect(record.hash, isNot(created['hash']));
    expect(record.name, 'Format Draft Updated');
    expect(record.format, 'txt');
    expect(record.folder, 'Class Notes');
    expect(await TextManifest.readText(record.storageFileName), 'New content');
  });

  test(
    'serializes conditional updates while the JSON store cache is cold',
    () async {
      final data = emptyWebData();
      data[ManifestTables.textRecords] = [
        {
          'id': 'cold-record',
          'hash': 'starting-hash',
          'name': 'Cold',
          'format': 'txt',
          'folder': '',
        },
      ];
      await WebFileStore.write(
        'manifest_database_data',
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
      );

      final results = await Future.wait([
        ManifestDatabase.updateTextRecordIfHash(
          'cold-record',
          'starting-hash',
          {'name': 'Cold', 'format': 'txt', 'folder': ''},
          {'hash': 'first-hash'},
        ),
        ManifestDatabase.updateTextRecordIfHash(
          'cold-record',
          'starting-hash',
          {'name': 'Cold', 'format': 'txt', 'folder': ''},
          {'hash': 'second-hash'},
        ),
      ]);

      expect(results.where((updated) => updated).length, 1);
      expect(results.where((updated) => !updated).length, 1);
      final record = (await ManifestDatabase.getAllTextRecords()).single;
      expect(['first-hash', 'second-hash'], contains(record['hash']));
    },
  );

  test(
    'checks persisted JSON against an update made by another web tab',
    () async {
      await ManifestDatabase.insertTextRecord({
        'id': 'cross-tab-record',
        'hash': 'starting-hash',
        'name': 'Original',
        'format': 'md',
        'folder': '',
      });
      await ManifestDatabase.getAllTextRecords(); // Prime this tab's cache.

      final otherTabData = emptyWebData();
      otherTabData[ManifestTables.textRecords] = [
        {
          'id': 'cross-tab-record',
          'hash': 'other-tab-hash',
          'name': 'Original',
          'format': 'md',
          'folder': '',
        },
      ];
      await WebFileStore.write(
        'manifest_database_data',
        Uint8List.fromList(utf8.encode(jsonEncode(otherTabData))),
      );

      final updated = await ManifestDatabase.updateTextRecordIfHash(
        'cross-tab-record',
        'starting-hash',
        {'name': 'Original', 'format': 'md', 'folder': ''},
        {'hash': 'stale-tab-hash'},
      );

      expect(updated, isFalse);
      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      expect(
        (persisted[ManifestTables.textRecords] as List).single['hash'],
        'other-tab-hash',
      );
    },
  );

  test(
    'does not delete replacement content committed by another web tab',
    () async {
      const original = 'Original content';
      const committed = 'Other tab content';
      final originalBytes = Uint8List.fromList(utf8.encode(original));
      final committedBytes = Uint8List.fromList(utf8.encode(committed));
      final originalHash = computeTextHash(originalBytes);
      final committedHash = computeTextHash(committedBytes);
      final record = TextRecord(
        id: 'cross-tab-content-cleanup',
        name: 'Original',
        hash: originalHash,
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.writeText(record.storageFileName, original);
      await TextManifest.addRecord(record);
      await TextManifest.loadRecords(); // Keep this tab's pre-update snapshot.
      await TextManifest.writeText('$committedHash.txt', committed);
      await _writePersistedTextRecord(record.id, {
        'hash': committedHash,
        'size': committedBytes.length,
      });

      final losingUpdate = TextRecord(
        id: record.id,
        name: record.name,
        hash: committedHash,
        format: record.format,
        createdAt: record.createdAt,
        modifiedAt: DateTime.utc(2026, 1, 2),
        size: committedBytes.length,
      );
      final replaced = await TextManifest.updateRecordIfHashWithContent(
        record.id,
        originalHash,
        {'name': record.name, 'format': record.format, 'folder': ''},
        losingUpdate,
        committedBytes,
      );

      expect(replaced, isFalse);
      expect(
        await TextManifest.readText('$committedHash.txt'),
        committed,
        reason: 'the winning tab still references these replacement bytes',
      );
    },
  );

  test(
    'metadata rename preserves a content update committed by another web tab',
    () async {
      const original = 'Original content';
      const committed = 'Other tab content';
      final originalBytes = Uint8List.fromList(utf8.encode(original));
      final committedBytes = Uint8List.fromList(utf8.encode(committed));
      final originalHash = computeTextHash(originalBytes);
      final committedHash = computeTextHash(committedBytes);
      final record = TextRecord(
        id: 'cross-tab-metadata',
        name: 'Original',
        hash: originalHash,
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.writeText(record.storageFileName, original);
      await TextManifest.addRecord(record);
      await TextManifest.loadRecords(); // Keep this tab's pre-update snapshot.
      await TextManifest.writeText('$committedHash.txt', committed);
      await _writePersistedTextRecord(record.id, {
        'hash': committedHash,
        'size': committedBytes.length,
      });

      await TextManifest.renameRecordWithFormat(record.id, 'Renamed', 'md');

      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      final updated = (persisted[ManifestTables.textRecords] as List).single
          as Map<String, dynamic>;
      expect(updated['name'], 'Renamed');
      expect(updated['format'], 'md');
      expect(updated['hash'], committedHash);
      expect(await TextManifest.readText('$committedHash.txt'), committed);
    },
  );

  test(
    'deleting a record preserves content referenced by another web tab',
    () async {
      const content = 'Shared content';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        id: 'cross-tab-delete-source',
        name: 'Original',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
      );
      await TextManifest.writeText(record.storageFileName, content);
      await TextManifest.addRecord(record);
      await TextManifest.loadRecords(); // Keep this tab's one-record snapshot.
      await _addPersistedTextRecord({
        ...record.toMap(),
        'id': 'cross-tab-delete-reference',
        'name': 'Other tab reference',
      });

      await TextManifest.deleteRecord(record.id);

      expect(await TextManifest.readText(record.storageFileName), content);
      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      expect(
        (persisted[ManifestTables.textRecords] as List).map(
          (row) => (row as Map)['id'],
        ),
        ['cross-tab-delete-reference'],
      );
    },
  );

  test(
    'batch deletion preserves content referenced by another web tab',
    () async {
      const content = 'Shared batch content';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        id: 'cross-tab-batch-delete-source',
        name: 'Original',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
      );
      await TextManifest.writeText(record.storageFileName, content);
      await TextManifest.addRecord(record);
      await TextManifest.loadRecords(); // Keep this tab's one-record snapshot.
      await _addPersistedTextRecord({
        ...record.toMap(),
        'id': 'cross-tab-batch-delete-reference',
        'name': 'Other tab reference',
      });

      await TextManifest.deleteRecords([record.id]);

      expect(await TextManifest.readText(record.storageFileName), content);
      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      expect(
        (persisted[ManifestTables.textRecords] as List).map(
          (row) => (row as Map)['id'],
        ),
        ['cross-tab-batch-delete-reference'],
      );
    },
  );

  test(
    'removing a folder preserves content added by another web tab',
    () async {
      const content = 'Folder content shared across tabs';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        id: 'cross-tab-folder-delete-source',
        name: 'Original',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        folder: 'To Delete',
      );
      await TextManifest.writeText(record.storageFileName, content);
      await TextManifest.addRecord(record);
      await TextManifest.loadRecords(); // Keep this tab's stale snapshot.
      await _addPersistedTextRecord({
        ...record.toMap(),
        'id': 'cross-tab-folder-delete-reference',
        'name': 'Other tab reference',
        'folder': 'Keep',
      });

      await TextManifest.removeFolder('To Delete');

      expect(await TextManifest.readText(record.storageFileName), content);
      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      expect(
        (persisted[ManifestTables.textRecords] as List).map(
          (row) => (row as Map)['id'],
        ),
        ['cross-tab-folder-delete-reference'],
      );
    },
  );

  test(
    'concurrent web-tab creation and folder removal keep committed text readable',
    () async {
      const content = 'Concurrent shared content';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final initialRecord = TextRecord(
        id: 'concurrent-folder-delete-source',
        name: 'Initial',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        folder: 'Concurrent Delete',
      );
      await TextManifest.addRecordWithContent(initialRecord, bytes);
      await TextManifest.loadRecords(); // Prime the first tab's snapshot.

      final secondTab = ManifestOperations<TextRecord>(
        manifestKey: 'text_manifest_second_tab',
        storageDirName: 'texts',
        fromMap: TextRecord.fromMap,
        tableName: ManifestTables.textRecords,
        toMap: (record) => record.toMap(),
      );
      final newRecord = TextRecord(
        id: 'concurrent-folder-delete-reference',
        name: 'Second tab',
        hash: initialRecord.hash,
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        folder: 'Concurrent Keep',
      );

      await Future.wait([
        TextManifest.removeFolder('Concurrent Delete'),
        secondTab.addTextRecordWithContent(newRecord, bytes),
      ]);

      expect(await TextManifest.readText(newRecord.storageFileName), content);
      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      expect(
        (persisted[ManifestTables.textRecords] as List).map(
          (row) => (row as Map)['id'],
        ),
        [newRecord.id],
      );
    },
  );

  test(
    'reading after another web tab replaces content reloads its manifest',
    () async {
      const original = 'Original text';
      const updated = 'Text committed by another tab';
      final originalBytes = Uint8List.fromList(utf8.encode(original));
      final updatedBytes = Uint8List.fromList(utf8.encode(updated));
      final record = TextRecord(
        id: 'cross-tab-fresh-read',
        name: 'Shared document',
        hash: computeTextHash(originalBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.addRecordWithContent(record, originalBytes);
      await TextManifest.loadRecords(); // Prime this tab's manifest cache.

      final updatedHash = computeTextHash(updatedBytes);
      await WebFileStore.write('texts/$updatedHash.txt', updatedBytes);
      await _writePersistedTextRecord(record.id, {
        'hash': updatedHash,
        'size': updatedBytes.length,
        'textLength': updated.length,
      });
      await WebFileStore.delete('texts/${record.hash}.txt');

      final response = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_read', {
          'record_id': record.id,
        }),
      ) as Map<String, dynamic>;

      expect(response['content'], updated);
      expect(response['hash'], updatedHash);
    },
  );

  test(
    'single deletion cleans the hash committed by another web tab',
    () async {
      const original = 'Original content';
      const replacement = 'Replaced content';
      final originalBytes = Uint8List.fromList(utf8.encode(original));
      final replacementBytes = Uint8List.fromList(utf8.encode(replacement));
      final record = TextRecord(
        id: 'cross-tab-single-delete-hash',
        name: 'Document',
        hash: computeTextHash(originalBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.addRecordWithContent(record, originalBytes);
      await TextManifest.loadRecords(); // Keep this tab's old hash cached.
      final replacementHash = computeTextHash(replacementBytes);
      await WebFileStore.write('texts/$replacementHash.txt', replacementBytes);
      await _writePersistedTextRecord(record.id, {
        'hash': replacementHash,
        'size': replacementBytes.length,
        'textLength': replacement.length,
      });

      await TextManifest.deleteRecord(record.id);

      expect(await TextManifest.readText('$replacementHash.txt'), isNull);
    },
  );

  test(
    'batch deletion cleans hashes committed by another web tab',
    () async {
      const original = 'Original batch content';
      const replacement = 'Replaced batch content';
      final originalBytes = Uint8List.fromList(utf8.encode(original));
      final replacementBytes = Uint8List.fromList(utf8.encode(replacement));
      final record = TextRecord(
        id: 'cross-tab-batch-delete-hash',
        name: 'Batch document',
        hash: computeTextHash(originalBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: originalBytes.length,
      );
      await TextManifest.addRecordWithContent(record, originalBytes);
      await TextManifest.loadRecords(); // Keep this tab's old hash cached.
      final replacementHash = computeTextHash(replacementBytes);
      await WebFileStore.write('texts/$replacementHash.txt', replacementBytes);
      await _writePersistedTextRecord(record.id, {
        'hash': replacementHash,
        'size': replacementBytes.length,
        'textLength': replacement.length,
      });

      await TextManifest.deleteRecords([record.id]);

      expect(await TextManifest.readText('$replacementHash.txt'), isNull);
    },
  );

  test(
    'folder removal preserves a record another web tab moved outside it',
    () async {
      const content = 'Keep this moved document';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        id: 'cross-tab-folder-move-out',
        name: 'Moved document',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: bytes.length,
        folder: 'To Delete/Subfolder',
      );
      await TextManifest.addRecordWithContent(record, bytes);
      await TextManifest.loadRecords(); // Keep this tab's old folder cached.
      await _writePersistedTextRecord(record.id, {'folder': 'Keep'});

      await TextManifest.removeFolder('To Delete');

      final persisted = jsonDecode(
        utf8.decode(
          (await WebFileStore.read('manifest_database_data'))!,
        ),
      ) as Map<String, dynamic>;
      final remaining = (persisted[ManifestTables.textRecords] as List).single
          as Map<String, dynamic>;
      expect(remaining['id'], record.id);
      expect(remaining['folder'], 'Keep');
      expect(await TextManifest.readText(record.storageFileName), content);
    },
  );

  test(
    'conditional update fails if stored metadata no longer matches',
    () async {
      await ManifestDatabase.insertTextRecord({
        'id': 'renamed-record',
        'hash': 'starting-hash',
        'name': 'Original',
        'format': 'md',
        'folder': '',
      });
      await ManifestDatabase.updateTextRecord('renamed-record', {
        'name': 'Renamed',
      });

      final updated = await ManifestDatabase.updateTextRecordIfHash(
        'renamed-record',
        'starting-hash',
        {'name': 'Original', 'format': 'md', 'folder': ''},
        {'hash': 'new-hash'},
      );

      expect(updated, isFalse);
      final record = (await ManifestDatabase.getAllTextRecords()).single;
      expect(record['name'], 'Renamed');
      expect(record['hash'], 'starting-hash');
    },
  );

  test('serializes metadata edits with conditional content updates', () async {
    await ManifestDatabase.insertTextRecord({
      'id': 'concurrent-rename',
      'hash': 'starting-hash',
      'name': 'Original',
      'format': 'md',
      'folder': '',
    });

    await Future.wait([
      ManifestDatabase.updateTextRecordIfHash(
        'concurrent-rename',
        'starting-hash',
        {'name': 'Original', 'format': 'md', 'folder': ''},
        {'hash': 'new-hash'},
      ),
      ManifestDatabase.updateTextRecord('concurrent-rename', {
        'name': 'Renamed',
      }),
    ]);

    final record = (await ManifestDatabase.getAllTextRecords()).single;
    expect(record['hash'], 'new-hash');
    expect(record['name'], 'Renamed');
  });

  test(
    'serializes TextManifest rename against a content replacement',
    () async {
      const originalContent = 'Original body';
      const replacementContent = 'Updated body';
      final originalHash = computeTextHash(
        Uint8List.fromList(utf8.encode(originalContent)),
      );
      final replacementHash = computeTextHash(
        Uint8List.fromList(utf8.encode(replacementContent)),
      );
      final original = TextRecord(
        id: 'manifest-race',
        name: 'Original',
        hash: originalHash,
        format: 'md',
        createdAt: DateTime.utc(2026),
        size: originalContent.length,
      );
      await TextManifest.writeText(original.storageFileName, originalContent);
      await TextManifest.addRecord(original);
      final replacement = TextRecord(
        id: original.id,
        name: original.name,
        hash: replacementHash,
        format: original.format,
        createdAt: original.createdAt,
        modifiedAt: DateTime.utc(2026, 1, 2),
        size: replacementContent.length,
      );

      await Future.wait([
        TextManifest.updateRecordIfHash(
            original.id,
            original.hash,
            {
              'name': original.name,
              'format': original.format,
              'folder': '',
            },
            replacement),
        TextManifest.renameRecord(original.id, 'Renamed'),
      ]);

      final record = (await TextManifest.loadRecords()).single;
      expect(record.hash, replacementHash);
      expect(record.name, 'Renamed');
    },
  );

  test('failed JSON persistence does not report or retain an update', () async {
    await ManifestDatabase.insertTextRecord({
      'id': 'write-failure-record',
      'hash': 'starting-hash',
      'name': 'Failed',
      'format': 'txt',
      'folder': '',
    });

    await expectLater(
      ManifestDatabase.updateTextRecordIfHash(
        'write-failure-record',
        'starting-hash',
        {'name': 'Failed', 'format': 'txt', 'folder': ''},
        {'hash': 'new-hash', 'unserializable': Object()},
      ),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    final record = (await ManifestDatabase.getAllTextRecords()).single;
    expect(record['hash'], 'starting-hash');
    expect(record.containsKey('unserializable'), isFalse);
  });

  test('failed JSON insert does not report or retain a new record', () async {
    await expectLater(
      ManifestDatabase.insertTextRecord({
        'id': 'insert-write-failure',
        'hash': 'starting-hash',
        'name': 'Failed',
        'format': 'txt',
        'folder': '',
        'unserializable': Object(),
      }),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    expect(await ManifestDatabase.getAllTextRecords(), isEmpty);
  });

  test('failed JSON metadata save throws and restores the record', () async {
    await ManifestDatabase.insertTextRecord({
      'id': 'metadata-write-failure',
      'hash': 'starting-hash',
      'name': 'Original',
      'format': 'txt',
      'folder': '',
    });

    await expectLater(
      ManifestDatabase.updateTextRecord('metadata-write-failure', {
        'name': 'Updated',
        'unserializable': Object(),
      }),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    final record = (await ManifestDatabase.getAllTextRecords()).single;
    expect(record['name'], 'Original');
    expect(record.containsKey('unserializable'), isFalse);
  });

  test(
    'cleans unreferenced content after the manifest transaction fails',
    () async {
      const oldContent = 'Original body';
      const newContent = 'Replacement body';
      final oldRecord = TextRecord(
        id: 'replacement-write-failure',
        name: 'Notes',
        hash: computeTextHash(Uint8List.fromList(utf8.encode(oldContent))),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: utf8.encode(oldContent).length,
      );
      final updatedRecord = TextRecord(
        id: oldRecord.id,
        name: oldRecord.name,
        hash: computeTextHash(Uint8List.fromList(utf8.encode(newContent))),
        format: oldRecord.format,
        createdAt: oldRecord.createdAt,
        modifiedAt: DateTime.utc(2026, 1, 2),
        size: utf8.encode(newContent).length,
      );
      await TextManifest.writeText(oldRecord.storageFileName, oldContent);
      await TextManifest.addRecord(oldRecord);

      WebFileStore.failNextTransformForTesting(StateError('write failed'));

      await expectLater(
        TextManifest.updateRecordIfHashWithContent(
          oldRecord.id,
          oldRecord.hash,
          {'name': oldRecord.name, 'format': oldRecord.format, 'folder': ''},
          updatedRecord,
          Uint8List.fromList(utf8.encode(newContent)),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await TextManifest.readText(updatedRecord.storageFileName),
        isNull,
      );
      expect(
        await TextManifest.readText(oldRecord.storageFileName),
        oldContent,
      );
    },
  );

  test(
    'failed JSON folder removal retains records, folders, and content files',
    () async {
      const content = 'Folder content survives manifest failure';
      final record = TextRecord(
        id: 'folder-delete-write-failure',
        name: 'Keep this note',
        hash: computeTextHash(Uint8List.fromList(utf8.encode(content))),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: utf8.encode(content).length,
        folder: 'Keep/This',
      );
      await TextManifest.writeText(record.storageFileName, content);
      await TextManifest.addRecord(record);
      await ManifestDatabase.insertFolder(
        'Keep/This',
        recordTable: 'text_records',
      );
      WebFileStore.failNextTransformForTesting(StateError('write failed'));

      await expectLater(
        TextManifest.removeFolder('Keep'),
        throwsA(isA<StateError>()),
      );

      expect(await TextManifest.readText(record.storageFileName), content);
      expect((await TextManifest.loadRecords()).single.id, record.id);
      expect(await TextManifest.getAllFolders(), contains('Keep/This'));
      expect(
        await ManifestDatabase.getAllFolders(recordTable: 'text_records'),
        contains('Keep/This'),
      );
    },
  );

  test(
    'failed JSON deletes retain text records, cache, and content files',
    () async {
      const content = 'Do not delete before manifest commit';
      final record = TextRecord(
        id: 'delete-write-failure',
        name: 'Keep this note',
        hash: computeTextHash(Uint8List.fromList(utf8.encode(content))),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: utf8.encode(content).length,
      );
      await TextManifest.writeText(record.storageFileName, content);
      await TextManifest.addRecord(record);
      WebFileStore.failNextTransformForTesting(StateError('write failed'));

      await expectLater(
        TextManifest.deleteRecord(record.id),
        throwsA(isA<StateError>()),
      );
      expect(await TextManifest.readText(record.storageFileName), content);
      expect((await TextManifest.loadRecords()).single.id, record.id);

      WebFileStore.failNextTransformForTesting(StateError('write failed'));
      await expectLater(
        TextManifest.deleteRecords([record.id]),
        throwsA(isA<StateError>()),
      );
      expect(await TextManifest.readText(record.storageFileName), content);
      expect((await TextManifest.loadRecords()).single.id, record.id);
    },
  );

  test(
    'conditional replacement honors legacy format and folder defaults',
    () async {
      await ManifestDatabase.insertTextRecord({
        'id': 'legacy-metadata',
        'hash': 'starting-hash',
        'name': 'Legacy',
      });

      final updated = await ManifestDatabase.updateTextRecordIfHash(
        'legacy-metadata',
        'starting-hash',
        {'name': 'Legacy', 'format': 'txt', 'folder': ''},
        {'hash': 'replacement-hash'},
      );

      expect(updated, isTrue);
      expect(
        (await ManifestDatabase.getAllTextRecords()).single['hash'],
        'replacement-hash',
      );
    },
  );

  test('read and search skip documents over the content byte limit', () async {
    const oversizedBytes = 1024 * 1024 + 1;
    final record = TextRecord(
      id: 'oversized-record',
      name: 'Large Notes',
      hash: 'a' * 32,
      format: 'txt',
      createdAt: DateTime.utc(2026),
      size: oversizedBytes,
    );
    await ManifestDatabase.insertTextRecord(record.toMap());

    final read = await TextStorageToolService.handleTool('stroom_space_read', {
      'record_id': record.id,
    });
    expect(read, contains('超过 1048576 字节'));

    final search = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_search', {
        'query': 'not-present',
      }),
    ) as Map<String, dynamic>;
    expect(search['content_search_skipped_oversized'], 1);
    expect(search['count'], 0);
  });

  test('bounds total body bytes scanned by one search', () async {
    final content = 'a' * 786432;
    for (var index = 0; index < 2; index++) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final record = TextRecord(
        id: 'search-budget-$index',
        name: 'Budget document $index',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026, 1, index + 1),
        size: bytes.length,
      );
      await TextManifest.writeFile(record.storageFileName, bytes);
      await TextManifest.addRecord(record);
    }

    final result = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_search', {
        'query': 'not-present',
      }),
    ) as Map<String, dynamic>;

    expect(result['content_search_truncated'], isTrue);
    expect(result['scanned'], 2);
    expect(result['count'], 0);
  });

  test(
    'stops body reads after stored content exceeds the remaining search budget',
    () async {
      final firstBytes = Uint8List.fromList(utf8.encode('a' * (768 * 1024)));
      final firstRecord = TextRecord(
        id: 'search-budget-first',
        name: 'First budget document',
        hash: computeTextHash(firstBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026, 1, 3),
        size: firstBytes.length,
      );
      await TextManifest.writeFile(firstRecord.storageFileName, firstBytes);
      await TextManifest.addRecord(firstRecord);

      final oversizedBytes = Uint8List.fromList(
        utf8.encode('b' * (384 * 1024)),
      );
      final oversizedRecord = TextRecord(
        id: 'search-budget-misreported',
        name: 'Misreported budget document',
        hash: computeTextHash(oversizedBytes),
        format: 'txt',
        createdAt: DateTime.utc(2026, 1, 2),
        size: 1,
      );
      await TextManifest.writeFile(
        oversizedRecord.storageFileName,
        oversizedBytes,
      );
      await TextManifest.addRecord(oversizedRecord);

      final laterMatch = TextRecord(
        id: 'search-budget-later-match',
        name: 'Later match',
        hash: computeTextHash(Uint8List.fromList(utf8.encode('needle'))),
        format: 'txt',
        createdAt: DateTime.utc(2026, 1, 1),
        size: 'needle'.length,
      );
      await TextManifest.writeFile(
        laterMatch.storageFileName,
        Uint8List.fromList(utf8.encode('needle')),
      );
      await TextManifest.addRecord(laterMatch);

      final result = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_search', {
          'query': 'needle',
        }),
      ) as Map<String, dynamic>;

      expect(result['content_search_truncated'], isTrue);
      expect(result['results'], isEmpty);
      expect(result['scanned'], 3);
    },
  );

  test('charges corrupted file bytes against the search budget', () async {
    const bodySize = 512 * 1024;
    for (var index = 0; index < 2; index++) {
      final expected = Uint8List(bodySize)..fillRange(0, bodySize, 97 + index);
      final corrupted = Uint8List(bodySize)..fillRange(0, bodySize, 120);
      final record = TextRecord(
        id: 'corrupt-search-budget-$index',
        name: 'Corrupt budget $index',
        hash: computeTextHash(expected),
        format: 'txt',
        createdAt: DateTime.utc(2026, 1, index + 2),
        size: bodySize,
      );
      await TextManifest.writeFile(record.storageFileName, expected);
      await TextManifest.addRecord(record);
      await TextManifest.writeFile(record.storageFileName, corrupted);
    }

    final matchingContent = 'needle in valid content';
    final matchingBytes = Uint8List.fromList(utf8.encode(matchingContent));
    final matching = TextRecord(
      id: 'after-corrupt-search-budget',
      name: 'Matching document',
      hash: computeTextHash(matchingBytes),
      format: 'txt',
      createdAt: DateTime.utc(2026, 1, 1),
      size: matchingBytes.length,
    );
    await TextManifest.writeFile(matching.storageFileName, matchingBytes);
    await TextManifest.addRecord(matching);

    final result = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_search', {
        'query': 'needle',
      }),
    ) as Map<String, dynamic>;

    expect(result['content_search_truncated'], isTrue);
    expect(result['results'], isEmpty);
  });

  test(
    'read and search enforce the byte limit against stored file size',
    () async {
      final bytes = Uint8List(1024 * 1024 + 1)
        ..fillRange(0, 1024 * 1024 + 1, 120);
      final record = TextRecord(
        id: 'stale-size-record',
        name: 'Stale Size',
        hash: computeTextHash(bytes),
        format: 'txt',
        createdAt: DateTime.utc(2026),
        size: 1,
      );
      await TextManifest.writeFile(record.storageFileName, bytes);
      await TextManifest.addRecord(record);

      final read = await TextStorageToolService.handleTool(
        'stroom_space_read',
        {'record_id': record.id},
      );
      expect(read, contains('超过 1048576 字节'));

      final search = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_search', {
          'query': 'xxxxxxxx',
        }),
      ) as Map<String, dynamic>;
      expect(search['content_search_skipped_oversized'], 1);
      expect(search['count'], 0);
    },
  );

  test('bounds search query and snippet lengths', () async {
    final query = 'x' * 256;
    final created = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_write', {
        'name': 'Long Note',
        'content': '${'a' * 1000}$query${'b' * 1000}',
      }),
    ) as Map<String, dynamic>;

    final result = jsonDecode(
      await TextStorageToolService.handleTool('stroom_space_search', {
        'query': query,
      }),
    ) as Map<String, dynamic>;
    final snippet = (result['results'] as List).single['snippet'] as String;
    expect(snippet.length, lessThanOrEqualTo(512));
    expect(snippet, contains(query));

    final tooLong = await TextStorageToolService.handleTool(
      'stroom_space_search',
      {'query': '${query}x'},
    );
    expect(tooLong, contains('最多支持 256 个字符'));
    expect(created['status'], 'created');
  });

  test(
    'rejects content whose bytes no longer match the manifest hash',
    () async {
      const original = 'Original lesson notes';
      const corrupted = 'tampered-marker lesson notes';
      final created = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_write', {
          'name': 'Lesson',
          'content': original,
          'format': 'txt',
        }),
      ) as Map<String, dynamic>;
      await TextManifest.writeText('${created['hash']}.txt', corrupted);

      final read = await TextStorageToolService.handleTool(
        'stroom_space_read',
        {'record_id': created['id']},
      );
      expect(read, contains('内容哈希'));
      expect(read, isNot(contains(corrupted)));

      final searched = jsonDecode(
        await TextStorageToolService.handleTool('stroom_space_search', {
          'query': 'tampered-marker',
        }),
      ) as Map<String, dynamic>;
      expect(searched['results'], isEmpty);

      final replacement =
          await TextStorageToolService.handleTool('stroom_space_write', {
        'record_id': created['id'],
        'expected_hash': created['hash'],
        'expected_metadata_hash': created['metadata_hash'],
        'name': 'Lesson',
        'content': 'Replacement content',
      });
      expect(replacement, startsWith('错误:'));
      expect(await TextManifest.readText('${created['hash']}.txt'), corrupted);
      expect((await TextManifest.loadRecords()).single.hash, created['hash']);
    },
  );

  test(
    'rejects corrupted record hashes before building a storage path',
    () async {
      final record = TextRecord(
        name: 'Corrupt',
        hash: '../outside',
        createdAt: DateTime.utc(2026),
        size: 0,
      );
      await ManifestDatabase.insertTextRecord(record.toMap());

      final result = await TextStorageToolService.handleTool(
        'stroom_space_read',
        {'record_id': record.id},
      );
      expect(result, contains('内容哈希无效'));
    },
  );
}
