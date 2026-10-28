import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/conversation_migration_service.dart';
import 'package:stroom/services/conversation_record_adapter.dart';
import 'package:stroom/services/conversation_repository.dart';
import 'package:stroom/services/conversation_repository_indexed_db.dart';
import 'package:stroom/services/conversation_repository_memory.dart';
import 'package:stroom/utils/web_file_store.dart';

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

class _FailingOrderMemoryRepository extends MemoryConversationRepository {
  bool failOrderWrites = false;

  @override
  Future<void> applySnapshotChanges({
    required List<ConversationRepositoryChange> changes,
    required List<String> conversationOrder,
    required List<String> deleteConversationIds,
  }) async {
    if (failOrderWrites) throw StateError('simulated order write failure');
    await super.applySnapshotChanges(
      changes: changes,
      conversationOrder: conversationOrder,
      deleteConversationIds: deleteConversationIds,
    );
  }
}

class _FailingMessageReadMemoryRepository extends MemoryConversationRepository {
  bool failReads = false;

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (failReads) throw StateError('simulated message read failure');
    return super.getMessages(conversationId, offset: offset, limit: limit);
  }
}

class _DelayedMessageReadMemoryRepository extends MemoryConversationRepository {
  final messageReadStarted = Completer<void>();
  final releaseMessageRead = Completer<void>();
  bool delayNextMessageRead = false;

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (delayNextMessageRead) {
      delayNextMessageRead = false;
      messageReadStarted.complete();
      await releaseMessageRead.future;
    }
    return super.getMessages(conversationId, offset: offset, limit: limit);
  }
}

class _CapturedDelayedMessageReadMemoryRepository
    extends MemoryConversationRepository {
  final messageReadStarted = Completer<void>();
  final releaseMessageRead = Completer<void>();
  bool delayNextMessageRead = false;

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    final captured = await super.getMessages(
      conversationId,
      offset: offset,
      limit: limit,
    );
    if (delayNextMessageRead) {
      delayNextMessageRead = false;
      messageReadStarted.complete();
      await releaseMessageRead.future;
    }
    return captured;
  }
}

class _DelayedSnapshotMemoryRepository extends MemoryConversationRepository {
  final snapshotStarted = Completer<void>();
  final releaseSnapshot = Completer<void>();
  bool delayNextSnapshot = false;

  @override
  Future<void> applySnapshotChanges({
    required List<ConversationRepositoryChange> changes,
    required List<String> conversationOrder,
    required List<String> deleteConversationIds,
  }) async {
    if (delayNextSnapshot) {
      delayNextSnapshot = false;
      snapshotStarted.complete();
      await releaseSnapshot.future;
    }
    await super.applySnapshotChanges(
      changes: changes,
      conversationOrder: conversationOrder,
      deleteConversationIds: deleteConversationIds,
    );
  }
}

class _MarkerCheckingMemoryRepository extends MemoryConversationRepository {
  bool markerPresentBeforeImport = false;

  @override
  Future<void> importConversation(StroomConversation conversation) async {
    final preferences = await SharedPreferences.getInstance();
    markerPresentBeforeImport =
        preferences.getString(ConversationMigrationService.stateKey) != null;
    await super.importConversation(conversation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationRepository', () {
    late MemoryConversationRepository repository;

    setUp(() async {
      repository = MemoryConversationRepository();
      await repository.initialize();
    });

    tearDown(() => repository.close());

    test('lists summaries and returns ordered message pages', () async {
      final conversation = StroomConversation(
        id: 'conversation-1',
        title: 'Paged history',
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2025, 1, 2),
      );
      await repository.upsertConversation(conversation);
      await repository.upsertConversation(
        StroomConversation(
          id: 'conversation-2',
          title: 'Second',
          createdAt: DateTime.utc(2025, 1, 1),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await repository.setConversationOrder([
        'conversation-1',
        'conversation-2',
      ]);
      await repository.replaceMessages('conversation-1', [
        _message('m1', 0),
        _message('m2', 1),
        _message('m3', 2),
      ]);

      final summaries = await repository.listSummaries();
      final firstPage = await repository.getMessages(
        'conversation-1',
        offset: 0,
        limit: 2,
      );
      final secondPage = await repository.getMessages(
        'conversation-1',
        offset: 2,
        limit: 2,
      );

      expect(summaries.map((summary) => summary.id), [
        'conversation-1',
        'conversation-2',
      ]);
      expect(summaries.first.messageCount, 3);
      expect(firstPage.map((message) => message.id), ['m1', 'm2']);
      expect(secondPage.map((message) => message.id), ['m3']);
    });

    test(
      'updating one message leaves other message records unchanged',
      () async {
        await repository.upsertConversation(
          StroomConversation(id: 'conversation-1', title: 'Edit'),
        );
        await repository.replaceMessages('conversation-1', [
          _message('m1', 0, 'before'),
          _message('m2', 1, 'keep'),
        ]);

        await repository.upsertMessage(
          'conversation-1',
          _message('m1', 0, 'after'),
        );

        final messages = await repository.getMessages('conversation-1');
        expect(messages.map((message) => message.id), ['m1', 'm2']);
        expect(messages.first.content.single.data['text'], 'after');
        expect(messages.last.content.single.data['text'], 'keep');
      },
    );

    test(
      'applies metadata and message deltas as one repository change',
      () async {
        await repository.importConversation(
          StroomConversation(
            id: 'atomic-conversation',
            title: 'Before',
            messages: [_message('keep', 0), _message('remove', 1)],
          ),
        );

        await repository.applyConversationChanges(
          StroomConversation(id: 'atomic-conversation', title: 'After'),
          upsertMessages: [_message('keep', 0, 'edited')],
          deleteMessageIds: const ['remove'],
        );

        expect(
          (await repository.getConversation('atomic-conversation'))!.title,
          'After',
        );
        final messages = await repository.getMessages('atomic-conversation');
        expect(messages.map((message) => message.id), ['keep']);
        expect(messages.single.content.single.data['text'], 'edited');
      },
    );

    test('integrity check reports a dangling media reference', () async {
      await repository.upsertConversation(
        StroomConversation(id: 'conversation-media', title: 'Media'),
      );
      await repository.upsertMessage(
        'conversation-media',
        StroomMessage(
          id: 'media-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [
            StroomContentPart(
              type: 'image',
              data: {'reference': 'attachments/missing.png'},
            ),
          ],
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (_) async => null,
      );

      expect(issues.single.reason, 'missing_media');
      expect(issues.single.reference, 'attachments/missing.png');
    });

    test('integrity check ignores external media URIs', () async {
      await repository.upsertConversation(
        StroomConversation(id: 'conversation-external-media', title: 'Remote'),
      );
      await repository.upsertMessage(
        'conversation-external-media',
        StroomMessage(
          id: 'external-media-message',
          role: 'assistant',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [
            StroomContentPart(
              type: 'image',
              data: {
                'reference': 'https://media.example/image.png',
                'thumbnailPath': 'https://media.example/image-thumb.png',
              },
            ),
            StroomContentPart.audio(
              reference: 'https://media.example/audio.mp3',
            ),
            StroomContentPart.video(
              reference: 'https://media.example/video.mp4',
            ),
            StroomContentPart.file(
              reference: 'https://media.example/document.pdf',
            ),
          ],
        ),
      );

      final readReferences = <String>[];
      final issues = await repository.checkIntegrity(
        readMedia: (reference) async {
          readReferences.add(reference);
          return null;
        },
      );

      expect(issues, isEmpty);
      expect(readReferences, isEmpty);
    });

    test(
      'integrity check uses local cache beside external media URI',
      () async {
        await repository.upsertConversation(
          StroomConversation(id: 'conversation-cached-media', title: 'Cached'),
        );
        await repository.upsertMessage(
          'conversation-cached-media',
          StroomMessage(
            id: 'cached-media-message',
            role: 'assistant',
            sequence: 0,
            createdAt: DateTime.utc(2025),
            content: [
              StroomContentPart(
                type: 'image',
                data: {
                  'reference': 'https://media.example/image.png',
                  'storagePath': 'attachments/cached.png',
                },
              ),
            ],
          ),
        );

        final readReferences = <String>[];
        final issues = await repository.checkIntegrity(
          readMedia: (reference) async {
            readReferences.add(reference);
            return Uint8List.fromList([1, 2, 3]);
          },
        );

        expect(issues, isEmpty);
        expect(readReferences, ['attachments/cached.png']);
      },
    );

    test('integrity check follows legacy attachment wrappers', () async {
      await repository.upsertConversation(
        StroomConversation(
          id: 'conversation-legacy-media',
          title: 'Legacy media',
        ),
      );
      await repository.upsertMessage(
        'conversation-legacy-media',
        StroomMessage(
          id: 'legacy-media-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [
            StroomContentPart(
              type: 'image',
              data: {
                'attachment': {'reference': 'attachments/photo.png'},
              },
            ),
          ],
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (reference) async => reference == 'attachments/photo.png'
            ? Uint8List.fromList([1, 2, 3])
            : null,
      );

      expect(issues, isEmpty);
    });

    test('integrity check follows legacy message attachment records', () async {
      await repository.upsertConversation(
        StroomConversation(
          id: 'conversation-legacy-record-media',
          title: 'Legacy record media',
        ),
      );
      await repository.upsertMessage(
        'conversation-legacy-record-media',
        StroomMessage(
          id: 'legacy-record-media-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          extensions: {
            'stroom.legacy': {
              'record': {
                'attachments': [
                  {
                    'storagePath': 'attachments/legacy-photo.png',
                    'thumbnailPath': 'attachments/legacy-photo-thumb.png',
                  },
                ],
              },
            },
          },
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (_) async => null,
      );

      expect(issues.map((issue) => issue.reference).toSet(), {
        'attachments/legacy-photo.png',
        'attachments/legacy-photo-thumb.png',
      });
    });

    test(
      'integrity checks migrated nested and sibling media paths once',
      () async {
        await repository.upsertConversation(
          StroomConversation(
            id: 'conversation-deduplicated-media',
            title: 'Media',
          ),
        );
        await repository.upsertMessage(
          'conversation-deduplicated-media',
          StroomMessage(
            id: 'deduplicated-media-message',
            role: 'user',
            sequence: 0,
            createdAt: DateTime.utc(2025),
            content: [
              StroomContentPart(
                type: 'image',
                data: {
                  'attachment': {'storagePath': 'attachments/original.png'},
                  'thumbnailPath': 'attachments/thumbnail.png',
                },
              ),
            ],
            extensions: const {
              'stroom.legacy': {
                'record': {
                  'attachments': [
                    {
                      'storagePath': 'attachments/original.png',
                      'thumbnailPath': 'attachments/thumbnail.png',
                    },
                  ],
                },
              },
            },
          ),
        );

        final issues = await repository.checkIntegrity(
          readMedia: (_) async => null,
        );

        expect(issues.map((issue) => issue.reference).toList(), [
          'attachments/original.png',
          'attachments/thumbnail.png',
        ]);
      },
    );

    test('external media references retain each sibling thumbnail', () async {
      await repository.upsertConversation(
        StroomConversation(
          id: 'conversation-external-thumbnails',
          title: 'Media',
        ),
      );
      await repository.upsertMessage(
        'conversation-external-thumbnails',
        StroomMessage(
          id: 'external-thumbnails-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [
            for (final thumbnail in const [
              'attachments/thumbnail-a.png',
              'attachments/thumbnail-b.png',
            ])
              StroomContentPart(
                type: 'image',
                data: {
                  'attachment': {
                    'reference': 'https://media.example/image.png',
                  },
                  'thumbnailPath': thumbnail,
                },
              ),
          ],
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (_) async => null,
      );

      expect(issues.map((issue) => issue.reference).toList(), [
        'attachments/thumbnail-a.png',
        'attachments/thumbnail-b.png',
      ]);
    });

    test('integrity check leaves open extension references opaque', () async {
      await repository.upsertConversation(
        StroomConversation(
          id: 'conversation-extension-reference',
          title: 'Protocol extension',
          extensions: {
            'example.protocol': {'reference': 'https://example.test/resource'},
          },
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (_) async => null,
      );

      expect(issues, isEmpty);
    });

    test('integrity check reports a missing derived thumbnail', () async {
      await repository.upsertConversation(
        StroomConversation(id: 'conversation-thumbnail', title: 'Thumbnail'),
      );
      await repository.upsertMessage(
        'conversation-thumbnail',
        StroomMessage(
          id: 'thumbnail-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [
            StroomContentPart(
              type: 'image',
              data: {
                'reference': 'attachments/image.png',
                'thumbnailPath': 'attachments/image-thumb.png',
              },
            ),
          ],
        ),
      );

      final issues = await repository.checkIntegrity(
        readMedia: (reference) async => reference == 'attachments/image.png'
            ? Uint8List.fromList([1, 2, 3])
            : null,
      );

      expect(issues.single.reference, 'attachments/image-thumb.png');
      expect(issues.single.reason, 'missing_media');
    });

    test(
      'backup export and restore retain message rows and list order',
      () async {
        await repository.upsertConversation(
          StroomConversation(id: 'backup-a', title: 'A'),
        );
        await repository.upsertConversation(
          StroomConversation(id: 'backup-b', title: 'B'),
        );
        await repository.setConversationOrder(['backup-b', 'backup-a']);
        await repository.setMigrationSourceHash('legacy-source-hash');
        await repository.replaceMessages('backup-a', [
          _message('backup-m1', 0),
        ]);
        final backup = await repository.exportData();

        final restored = MemoryConversationRepository();
        await restored.restoreData(backup);

        expect((await restored.listSummaries()).map((summary) => summary.id), [
          'backup-b',
          'backup-a',
        ]);
        expect((await restored.getMessages('backup-a')).single.id, 'backup-m1');
        expect(await restored.migrationSourceHash(), 'legacy-source-hash');
        await restored.close();
      },
    );
  });

  test('IndexedDB backup restore preserves empty migration marker', () async {
    WebFileStore.enableTestMode();
    addTearDown(WebFileStore.disableTestMode);
    final repository = IndexedDbConversationRepository();
    await repository.initialize();
    await repository.upsertConversation(
      StroomConversation(id: 'restored-authoritative', title: 'Restored'),
    );
    await repository.setMigrationSourceHash('');
    final backup = await repository.exportData();

    final restored = IndexedDbConversationRepository();
    await restored.initialize();
    await restored.restoreData(backup);

    expect(await restored.migrationSourceHash(), '');
    await repository.close();
    await restored.close();
  });

  test(
    'repository backup preserves opaque message conversationId fields',
    () async {
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.upsertConversation(
        StroomConversation(id: 'opaque-owner', title: 'Opaque owner'),
      );
      await repository.upsertMessage(
        'opaque-owner',
        StroomMessage(
          id: 'opaque-message',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [StroomContentPart.text('body')],
          extraFields: const {'conversationId': 'opaque-vendor-value'},
        ),
      );
      final backup = await repository.exportData();
      final exportedMessage = (backup['messages'] as List).single as Map;

      expect(exportedMessage['conversationId'], 'opaque-owner');
      expect(
        (exportedMessage['record'] as Map)['conversationId'],
        'opaque-vendor-value',
      );
      final restored = MemoryConversationRepository();
      await restored.restoreData(backup);

      expect(
        (await restored.getMessages(
          'opaque-owner',
        )).single.extraFields['conversationId'],
        'opaque-vendor-value',
      );
      await repository.close();
      await restored.close();
    },
  );

  test('repository restore accepts legacy flat message backup rows', () async {
    final repository = MemoryConversationRepository();

    await repository.restoreData({
      'schemaVersion': 1,
      'conversations': [
        StroomConversation(id: 'legacy-owner', title: 'Legacy').toMap(),
      ],
      'messages': [
        {
          'conversationId': 'legacy-owner',
          ..._message('legacy-flat-message', 0).toMap(),
        },
      ],
    });

    expect(
      (await repository.getMessages('legacy-owner')).single.id,
      'legacy-flat-message',
    );
    await repository.close();
  });

  test('IndexedDB pages preserve signed numeric sequence order', () async {
    WebFileStore.enableTestMode();
    addTearDown(WebFileStore.disableTestMode);
    final repository = IndexedDbConversationRepository();
    await repository.initialize();
    await repository.upsertConversation(
      StroomConversation(id: 'indexeddb-order', title: 'Sequence order'),
    );
    await repository.replaceMessages('indexeddb-order', [
      _message('negative-two', -2),
      _message('negative-one', -1),
      _message('zero', 0),
      _message('large-before', 999999999999),
      _message('large-after', 1000000000000),
    ]);

    final messages = await repository.getMessages('indexeddb-order');

    expect(messages.map((message) => message.id), [
      'negative-two',
      'negative-one',
      'zero',
      'large-before',
      'large-after',
    ]);
    await repository.close();
  });

  group('ConversationMigrationService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('marks an empty legacy source as repository authoritative', () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = MemoryConversationRepository();
      await repository.initialize();

      final initial = await ConversationMigrationService(
        repository,
      ).migrate(preferences);
      await repository.importConversation(
        StroomConversation(
          id: 'fresh-conversation',
          title: 'Fresh',
          messages: [_message('fresh-message', 0)],
        ),
      );
      final retry = await ConversationMigrationService(
        repository,
      ).migrate(preferences);

      expect(initial.verified, isTrue);
      expect(await repository.migrationSourceHash(), '');
      expect(retry.conversationCount, 1);
      expect(retry.messageCount, 1);
      await repository.close();
    });

    test(
      'writes the migration source marker before importing the first batch',
      () async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'conversations',
          '[${_legacyConversation('marked', ['message'])}]',
        );
        final repository = _MarkerCheckingMemoryRepository();
        await repository.initialize();

        await ConversationMigrationService(repository).migrate(preferences);

        expect(repository.markerPresentBeforeImport, isTrue);
        await repository.close();
      },
    );

    test(
      'backs up source, resumes an interrupted batch, then verifies import',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final raw =
            '[${_legacyConversation('c1', ['m1', 'm2'])},'
            '${_legacyConversation('c2', ['m3'])}]';
        await preferences.setString('conversations', raw);
        final repository = MemoryConversationRepository();
        await repository.initialize();
        var failed = false;
        final migration = ConversationMigrationService(
          repository,
          batchSize: 1,
          beforeBatchCommit: (batchIndex) async {
            if (batchIndex == 1 && !failed) {
              failed = true;
              throw StateError('simulated interruption');
            }
          },
        );

        await expectLater(migration.migrate(preferences), throwsStateError);
        expect(preferences.getString('conversations'), raw);
        expect(preferences.getString('conversations.migration.backup'), raw);
        expect(await repository.countConversations(), 1);

        migration.beforeBatchCommit = null;
        final result = await migration.migrate(preferences);

        expect(result.verified, isTrue);
        expect(result.conversationCount, 2);
        expect(result.messageCount, 3);
        expect(preferences.getString('conversations'), raw);
        expect(await repository.countConversations(), 2);
        expect((await repository.getMessages('c1')).map((m) => m.id), [
          'm1',
          'm2',
        ]);
        expect(
          (await repository.listSummaries()).map((summary) => summary.id),
          ['c1', 'c2'],
        );

        final retry = await migration.migrate(preferences);
        expect(retry.verified, isTrue);
        expect(await repository.countConversations(), 2);

        await repository.importConversation(
          StroomConversation(
            id: 'created-after-migration',
            title: 'New repository conversation',
            messages: [_message('new-message', 0)],
          ),
        );
        final afterRepositoryWrite = await migration.migrate(preferences);
        expect(afterRepositoryWrite.verified, isTrue);
        expect(await repository.countConversations(), 3);
        expect(
          (await repository.getConversation('created-after-migration'))?.title,
          'New repository conversation',
        );

        final resetRepository = MemoryConversationRepository();
        final recovered = await ConversationMigrationService(
          resetRepository,
        ).migrate(preferences);
        expect(recovered.verified, isTrue);
        expect(await resetRepository.countConversations(), 2);
        expect(
          (await resetRepository.getMessages(
            'c1',
          )).map((message) => message.id),
          ['m1', 'm2'],
        );
        await resetRepository.close();
        await repository.close();
      },
    );

    test(
      'recovers from the retained backup when the live source disappears',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final raw =
            '[${_legacyConversation('c1', ['m1'])},'
            '${_legacyConversation('c2', ['m2'])}]';
        await preferences.setString('conversations', raw);
        final repository = MemoryConversationRepository();
        await repository.initialize();
        final migration = ConversationMigrationService(
          repository,
          batchSize: 1,
          beforeBatchCommit: (batchIndex) async {
            if (batchIndex == 1) throw StateError('simulated interruption');
          },
        );

        await expectLater(migration.migrate(preferences), throwsStateError);
        await preferences.remove('conversations');
        migration.beforeBatchCommit = null;

        final result = await migration.migrate(preferences);

        expect(result.verified, isTrue);
        expect(result.conversationCount, 2);
        expect(await repository.countConversations(), 2);
        expect((await repository.getMessages('c2')).single.id, 'm2');
        await repository.close();
      },
    );

    test(
      'restarts an incomplete migration when repository rows were reset',
      () async {
        final preferences = await SharedPreferences.getInstance();
        final raw =
            '[${_legacyConversation('c1', ['m1'])},'
            '${_legacyConversation('c2', ['m2'])}]';
        await preferences.setString('conversations', raw);
        final interruptedRepository = MemoryConversationRepository();
        await interruptedRepository.initialize();
        await expectLater(
          ConversationMigrationService(
            interruptedRepository,
            batchSize: 1,
            beforeBatchCommit: (batchIndex) async {
              if (batchIndex == 1) throw StateError('simulated interruption');
            },
          ).migrate(preferences),
          throwsStateError,
        );

        final resetRepository = MemoryConversationRepository();
        await resetRepository.initialize();
        final result = await ConversationMigrationService(
          resetRepository,
          batchSize: 1,
        ).migrate(preferences);

        expect(result.verified, isTrue);
        expect(result.conversationCount, 2);
        expect((await resetRepository.getMessages('c1')).single.id, 'm1');
        expect((await resetRepository.getMessages('c2')).single.id, 'm2');
        await interruptedRepository.close();
        await resetRepository.close();
      },
    );

    test('reconciles stale rows when the legacy source changes', () async {
      final preferences = await SharedPreferences.getInstance();
      final originalConversation =
          Map<String, dynamic>.from(
              jsonDecode(_legacyConversation('stale', ['old'])) as Map,
            )
            ..['draftAttachments'] = [
              {'storagePath': 'https://media.example/original.png'},
            ];
      final originalSource = jsonEncode([
        originalConversation,
        jsonDecode(_legacyConversation('interrupted', ['pending'])),
      ]);
      await preferences.setString('conversations', originalSource);
      final repository = MemoryConversationRepository();
      await repository.initialize();
      final interruptedMigration = ConversationMigrationService(
        repository,
        batchSize: 1,
        beforeBatchCommit: (batchIndex) async {
          if (batchIndex == 1) throw StateError('simulated interruption');
        },
      );
      await expectLater(
        interruptedMigration.migrate(preferences),
        throwsStateError,
      );
      expect(await repository.countConversations(), 1);

      final replacementConversation =
          Map<String, dynamic>.from(
              jsonDecode(_legacyConversation('replacement', ['new'])) as Map,
            )
            ..['draftAttachments'] = [
              {'storagePath': 'https://media.example/replacement.png'},
            ];
      final replacementSource = jsonEncode([replacementConversation]);
      await preferences.setString('conversations', replacementSource);
      final result = await ConversationMigrationService(
        repository,
      ).migrate(preferences);

      expect(result.verified, isTrue);
      expect(await repository.countConversations(), 1);
      expect((await repository.listSummaries()).map((summary) => summary.id), [
        'replacement',
      ]);
      expect((await repository.getMessages('replacement')).single.id, 'new');
      expect(
        preferences.getString(ConversationMigrationService.backupKey),
        replacementSource,
      );
      final attachmentManifest =
          jsonDecode(
                preferences.getString(
                  ConversationMigrationService.attachmentManifestBackupKey,
                )!,
              )
              as List;
      expect(attachmentManifest, hasLength(1));
      expect(
        attachmentManifest.single['storagePath'],
        'https://media.example/replacement.png',
      );
      await repository.close();
    });

    test(
      'externalizes inline draft payloads before repository storage',
      () async {
        final previousPathProvider = PathProviderPlatform.instance;
        final directory = Directory.systemTemp.createTempSync(
          'draft_migration_',
        );
        PathProviderPlatform.instance = _TestPathProvider(directory.path);
        addTearDown(() {
          PathProviderPlatform.instance = previousPathProvider;
          directory.deleteSync(recursive: true);
        });
        final preferences = await SharedPreferences.getInstance();
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final raw = jsonEncode([
          {
            'id': 'draft-conversation',
            'title': 'Draft',
            'draftAttachments': [
              {
                'id': 'draft-attachment',
                'fileName': 'draft.png',
                'mimeType': 'image/png',
                'fileType': 'image',
                'hash': '',
                'storagePath': '',
                'fileSize': bytes.length,
                'base64Data': base64Encode(bytes),
              },
            ],
          },
        ]);
        await preferences.setString('conversations', raw);
        final repository = MemoryConversationRepository();
        await repository.initialize();

        final result = await ConversationMigrationService(
          repository,
        ).migrate(preferences);

        expect(result.verified, isTrue);
        final stored = await repository.getConversation('draft-conversation');
        final legacy = stored!.extensions['stroom.legacyConversation'] as Map;
        final attachment = (legacy['draftAttachments'] as List).single as Map;
        expect(attachment['base64Data'], isNull);
        expect(attachment['storagePath'], isNotEmpty);
        expect(
          await AttachmentStorage.readFile(attachment['storagePath'] as String),
          bytes,
        );
        final manifest =
            jsonDecode(
                  preferences.getString(
                    ConversationMigrationService.attachmentManifestBackupKey,
                  )!,
                )
                as List;
        expect(manifest.single, isNot(contains('base64Data')));
        await repository.close();
      },
    );

    test(
      'reuses an externalized draft attachment after an interrupted migration',
      () async {
        final previousPathProvider = PathProviderPlatform.instance;
        final directory = Directory.systemTemp.createTempSync(
          'draft_migration_retry_',
        );
        PathProviderPlatform.instance = _TestPathProvider(directory.path);
        addTearDown(() {
          PathProviderPlatform.instance = previousPathProvider;
          directory.deleteSync(recursive: true);
        });
        final preferences = await SharedPreferences.getInstance();
        final bytes = Uint8List.fromList([5, 6, 7, 8]);
        final raw = jsonEncode([
          {
            'id': 'draft-retry-conversation',
            'title': 'Draft retry',
            'draftAttachments': [
              {
                'id': 'draft-retry-attachment',
                'fileName': 'draft.png',
                'mimeType': 'image/png',
                'fileType': 'image',
                'storagePath': '',
                'fileSize': bytes.length,
                'base64Data': base64Encode(bytes),
              },
            ],
          },
        ]);
        await preferences.setString('conversations', raw);
        final repository = MemoryConversationRepository();
        await repository.initialize();
        final migration = ConversationMigrationService(
          repository,
          beforeBatchCommit: (batchIndex) async {
            if (batchIndex == 0) throw StateError('simulated interruption');
          },
        );

        await expectLater(migration.migrate(preferences), throwsStateError);
        final firstManifest =
            jsonDecode(
                  preferences.getString(
                    ConversationMigrationService.attachmentManifestBackupKey,
                  )!,
                )
                as List;
        expect(firstManifest, hasLength(1));
        final firstPath = firstManifest.single['storagePath'] as String;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        migration.beforeBatchCommit = null;

        final result = await migration.migrate(preferences);
        final finalManifest =
            jsonDecode(
                  preferences.getString(
                    ConversationMigrationService.attachmentManifestBackupKey,
                  )!,
                )
                as List;

        expect(result.verified, isTrue);
        expect(finalManifest, hasLength(1));
        expect(finalManifest.single['storagePath'], firstPath);
        await repository.close();
      },
    );

    test('replaces a stale draft path with its valid inline payload', () async {
      final previousPathProvider = PathProviderPlatform.instance;
      final directory = Directory.systemTemp.createTempSync(
        'draft_migration_stale_',
      );
      PathProviderPlatform.instance = _TestPathProvider(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = previousPathProvider;
        directory.deleteSync(recursive: true);
      });
      final preferences = await SharedPreferences.getInstance();
      final staleBytes = Uint8List.fromList([1, 2, 3]);
      final expectedBytes = Uint8List.fromList([9, 8, 7]);
      final stalePath = await AttachmentStorage.saveFile(
        'draft.png',
        staleBytes,
      );
      await preferences.setString(
        'conversations',
        jsonEncode([
          {
            'id': 'stale-draft-conversation',
            'title': 'Stale draft',
            'draftAttachments': [
              {
                'id': 'stale-draft-attachment',
                'fileName': 'draft.png',
                'mimeType': 'image/png',
                'fileType': 'image',
                'hash': '',
                'storagePath': stalePath,
                'base64Data': base64Encode(expectedBytes),
              },
            ],
          },
        ]),
      );
      final repository = MemoryConversationRepository();
      await repository.initialize();

      final result = await ConversationMigrationService(
        repository,
      ).migrate(preferences);

      final stored = await repository.getConversation(
        'stale-draft-conversation',
      );
      final legacy = stored!.extensions['stroom.legacyConversation'] as Map;
      final attachment = (legacy['draftAttachments'] as List).single as Map;
      final migratedPath = attachment['storagePath'] as String;
      expect(result.verified, isTrue);
      expect(migratedPath, isNot(stalePath));
      expect(await AttachmentStorage.readFile(migratedPath), expectedBytes);
      await repository.close();
    });
  });

  test(
    'chat notifier loads the latest page and older pages on demand',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'paged-conversation',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'paged-conversation',
          title: 'Paged',
          messages: [
            for (var index = 0; index < 45; index++) _message('p$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;

      final active = container.read(conversationsProvider).single;
      expect(active.messages.map((message) => message.id).toList(), [
        for (var index = 25; index < 45; index++) 'p$index',
      ]);
      final fullContext = await notifier.loadFullMessagesForContext(
        'paged-conversation',
      );
      expect(fullContext.map((message) => message.id).toList(), [
        for (var index = 0; index < 45; index++) 'p$index',
      ]);
      expect(
        container.read(conversationsProvider).single.messages,
        hasLength(20),
      );
      await notifier.updateMessages(
        'paged-conversation',
        List<ChatMessage>.from(active.messages),
      );
      expect(
        await repository.countMessages(conversationId: 'paged-conversation'),
        45,
      );
      expect(
        notifier.hasEarlierRepositoryMessages('paged-conversation'),
        isTrue,
      );

      final middlePage = await notifier.loadEarlierRepositoryMessages(
        'paged-conversation',
      );
      expect(middlePage.first.id, 'p5');
      expect(middlePage.last.id, 'p24');
      notifier.commitLoadedRepositoryMessages('paged-conversation', middlePage);
      expect(
        notifier.hasEarlierRepositoryMessages('paged-conversation'),
        isTrue,
      );

      final firstPage = await notifier.loadEarlierRepositoryMessages(
        'paged-conversation',
      );
      expect(firstPage.map((message) => message.id).toList(), [
        for (var index = 0; index < 5; index++) 'p$index',
      ]);
      notifier.commitLoadedRepositoryMessages('paged-conversation', firstPage);
      expect(
        notifier.hasEarlierRepositoryMessages('paged-conversation'),
        isFalse,
      );

      final latestPage = await notifier.reloadLatestMessagePage(
        'paged-conversation',
      );
      expect(latestPage.map((message) => message.id).toList(), [
        for (var index = 25; index < 45; index++) 'p$index',
      ]);
      expect(
        container.read(conversationsProvider).single.messages,
        hasLength(20),
      );

      expect(
        await notifier.loadMessagesAroundMessage('paged-conversation', 'p32'),
        isTrue,
      );
      expect(
        container
            .read(conversationsProvider)
            .single
            .messages
            .map((message) => message.id),
        [for (var index = 20; index < 40; index++) 'p$index'],
      );
      expect(
        notifier.hasEarlierRepositoryMessages('paged-conversation'),
        isTrue,
      );
      expect(notifier.hasLaterRepositoryMessages('paged-conversation'), isTrue);
      final newerPage = await notifier.loadLaterRepositoryMessages(
        'paged-conversation',
      );
      expect(newerPage.map((message) => message.id).toList(), [
        for (var index = 40; index < 45; index++) 'p$index',
      ]);
      notifier.commitLoadedLaterRepositoryMessages(
        'paged-conversation',
        newerPage,
      );
      expect(
        notifier.hasLaterRepositoryMessages('paged-conversation'),
        isFalse,
      );
      expect(
        container
            .read(conversationsProvider)
            .single
            .messages
            .map((message) => message.id),
        [for (var index = 20; index < 45; index++) 'p$index'],
      );
    },
  );

  test(
    'stale repository page read cannot replace newer complete history',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'stale-page-load',
      });
      final repository = _CapturedDelayedMessageReadMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'stale-page-load',
          title: 'Stale page load',
          messages: [
            for (var index = 0; index < 45; index++) _message('s$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      repository.delayNextMessageRead = true;
      final staleReload = notifier.reloadLatestMessagePage('stale-page-load');
      await repository.messageReadStarted.future;

      final completeHistory = await notifier.loadFullMessagesForContext(
        'stale-page-load',
      );
      await notifier.updateMessages(
        'stale-page-load',
        completeHistory.take(10).toList(),
        completeHistorySnapshot: true,
      );
      repository.releaseMessageRead.complete();
      await staleReload;

      expect(
        container
            .read(conversationsProvider)
            .single
            .messages
            .map((message) => message.id)
            .toList(),
        [for (var index = 0; index < 10; index++) 's$index'],
      );
      expect(
        await repository.countMessages(conversationId: 'stale-page-load'),
        10,
      );
    },
  );

  test('stale search page cannot replace a newer latest page', () async {
    SharedPreferences.setMockInitialValues({
      'active_conversation_id': 'stale-search-page',
    });
    final repository = _CapturedDelayedMessageReadMemoryRepository();
    await repository.initialize();
    await repository.importConversation(
      StroomConversation(
        id: 'stale-search-page',
        title: 'Stale search page',
        messages: [
          for (var index = 0; index < 45; index++) _message('q$index', index),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await repository.close();
    });

    final notifier = container.read(conversationsProvider.notifier);
    await notifier.ready;
    repository.delayNextMessageRead = true;
    final staleSearchPage = notifier.loadMessagesAroundMessage(
      'stale-search-page',
      'q0',
    );
    await repository.messageReadStarted.future;

    await notifier.reloadLatestMessagePage('stale-search-page');
    repository.releaseMessageRead.complete();

    expect(await staleSearchPage, isFalse);
    expect(
      container
          .read(conversationsProvider)
          .single
          .messages
          .map((message) => message.id)
          .toList(),
      [for (var index = 25; index < 45; index++) 'q$index'],
    );
  });

  test(
    'new messages after an older page use the repository sequence high-water mark',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'older-page-sequence',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'older-page-sequence',
          title: 'Older page sequence',
          messages: [
            for (var index = 0; index < 45; index++) _message('h$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      expect(
        await notifier.loadMessagesAroundMessage('older-page-sequence', 'h0'),
        isTrue,
      );
      final olderPage = List<ChatMessage>.from(
        container.read(conversationsProvider).single.messages,
      );
      olderPage.add(
        ChatMessage(
          id: 'hzz-new',
          role: 'user',
          content: 'new message',
          createdAt: DateTime(2026),
        ),
      );
      await notifier.updateMessages('older-page-sequence', olderPage);

      final persisted = await repository.getMessages('older-page-sequence');
      expect(persisted.last.id, 'hzz-new');
    },
  );

  test('complete history snapshots delete omitted repository rows', () async {
    SharedPreferences.setMockInitialValues({
      'active_conversation_id': 'complete-snapshot',
    });
    final repository = MemoryConversationRepository();
    await repository.initialize();
    await repository.importConversation(
      StroomConversation(
        id: 'complete-snapshot',
        title: 'Complete snapshot',
        messages: [
          for (var index = 0; index < 45; index++) _message('c$index', index),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await repository.close();
    });

    final notifier = container.read(conversationsProvider.notifier);
    await notifier.ready;
    final fullHistory = await notifier.loadFullMessagesForContext(
      'complete-snapshot',
    );
    await notifier.updateMessages(
      'complete-snapshot',
      fullHistory.take(10).toList(),
      completeHistorySnapshot: true,
    );

    final persisted = await repository.getMessages('complete-snapshot');
    expect(persisted.map((message) => message.id), [
      for (var index = 0; index < 10; index++) 'c$index',
    ]);
  });

  test(
    'complete history snapshots persist edits after a full history read',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'complete-snapshot-edits',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'complete-snapshot-edits',
          title: 'Complete snapshot edits',
          messages: [
            for (var index = 0; index < 45; index++) _message('e$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final loadedHistory = await notifier.loadFullMessagesForContext(
        'complete-snapshot-edits',
      );
      expect(loadedHistory, hasLength(45));
      final editedHistory = [
        for (var index = 0; index < 45; index++)
          ChatMessage(
            id: 'e$index',
            role: 'user',
            content: index == 0 ? 'edited' : 'text',
            createdAt: DateTime.utc(2025, 1, 1, 0, index),
          ),
      ];
      await notifier.updateMessages(
        'complete-snapshot-edits',
        editedHistory,
        completeHistorySnapshot: true,
      );

      final persisted = await repository.getMessages('complete-snapshot-edits');
      expect(persisted.first.content.single.data['text'], 'edited');
    },
  );

  test(
    'failed complete snapshots do not delete after a paged reload',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'failed-complete-snapshot',
      });
      final repository = _FailingOrderMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'failed-complete-snapshot',
          title: 'Failed complete snapshot',
          messages: [
            for (var index = 0; index < 45; index++) _message('f$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final fullHistory = await notifier.loadFullMessagesForContext(
        'failed-complete-snapshot',
      );
      repository.failOrderWrites = true;
      await notifier.updateMessages(
        'failed-complete-snapshot',
        fullHistory.take(10).toList(),
        completeHistorySnapshot: true,
      );
      repository.failOrderWrites = false;

      await notifier.reloadLatestMessagePage('failed-complete-snapshot');
      await notifier.loadFullMessagesForContext('failed-complete-snapshot');
      final pagedMessages = container
          .read(conversationsProvider)
          .single
          .messages;
      await notifier.updateMessages('failed-complete-snapshot', pagedMessages);

      expect(
        await repository.countMessages(
          conversationId: 'failed-complete-snapshot',
        ),
        45,
      );
    },
  );

  test(
    'failed complete snapshot intent survives a retry of its full state',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'failed-complete-retry',
      });
      final repository = _FailingOrderMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'failed-complete-retry',
          title: 'Retry complete snapshot',
          messages: [
            for (var index = 0; index < 45; index++) _message('r$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final fullHistory = await notifier.loadFullMessagesForContext(
        'failed-complete-retry',
      );
      repository.failOrderWrites = true;
      await notifier.updateMessages(
        'failed-complete-retry',
        fullHistory.take(10).toList(),
        completeHistorySnapshot: true,
      );
      repository.failOrderWrites = false;
      final retryState = container.read(conversationsProvider).single.messages;
      await notifier.updateMessages('failed-complete-retry', retryState);

      expect(
        await repository.countMessages(conversationId: 'failed-complete-retry'),
        10,
      );
    },
  );

  test('queued complete snapshots retain a newer deletion marker', () async {
    SharedPreferences.setMockInitialValues({
      'active_conversation_id': 'queued-complete-snapshot',
    });
    final repository = _DelayedSnapshotMemoryRepository();
    await repository.initialize();
    await repository.importConversation(
      StroomConversation(
        id: 'queued-complete-snapshot',
        title: 'Queued snapshot',
        messages: [
          for (var index = 0; index < 45; index++) _message('q$index', index),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await repository.close();
    });

    final notifier = container.read(conversationsProvider.notifier);
    await notifier.ready;
    final fullHistory = await notifier.loadFullMessagesForContext(
      'queued-complete-snapshot',
    );
    repository.delayNextSnapshot = true;
    final firstWrite = notifier.updateMessages(
      'queued-complete-snapshot',
      fullHistory,
      completeHistorySnapshot: true,
    );
    await repository.snapshotStarted.future;
    final secondWrite = notifier.updateMessages(
      'queued-complete-snapshot',
      fullHistory.take(10).toList(),
      completeHistorySnapshot: true,
    );
    repository.releaseSnapshot.complete();
    await firstWrite;
    await secondWrite;

    expect(
      (await repository.getMessages(
        'queued-complete-snapshot',
      )).map((message) => message.id),
      [for (var index = 0; index < 10; index++) 'q$index'],
    );
  });

  test(
    'queued paged snapshots cannot consume a later deletion marker',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'queued-paged-snapshot',
      });
      final repository = _DelayedSnapshotMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'queued-paged-snapshot',
          title: 'Queued paged snapshot',
          messages: [
            for (var index = 0; index < 45; index++) _message('q$index', index),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final fullHistory = await notifier.loadFullMessagesForContext(
        'queued-paged-snapshot',
      );
      final pagedMessages = container
          .read(conversationsProvider)
          .single
          .messages;
      final changedPage = pagedMessages
          .map(
            (message) => message.id == pagedMessages.first.id
                ? message.copyWith(content: 'queue blocker')
                : message,
          )
          .toList();

      repository.delayNextSnapshot = true;
      final blockingWrite = notifier.updateMessages(
        'queued-paged-snapshot',
        changedPage,
      );
      await repository.snapshotStarted.future;
      final queuedPagedWrite = notifier.updateMessages(
        'queued-paged-snapshot',
        changedPage,
      );
      final truncationWrite = notifier.updateMessages(
        'queued-paged-snapshot',
        fullHistory.take(10).toList(),
        completeHistorySnapshot: true,
      );
      repository.releaseSnapshot.complete();
      await blockingWrite;
      await queuedPagedWrite;
      await truncationWrite;

      expect(
        (await repository.getMessages(
          'queued-paged-snapshot',
        )).map((message) => message.id),
        [for (var index = 0; index < 10; index++) 'q$index'],
      );
    },
  );

  test(
    'attachment reference lookup includes unloaded repository pages',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'paged-attachment-references',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      final sharedAttachment = Attachment(
        fileName: 'shared.txt',
        mimeType: 'text/plain',
        fileType: 'text',
        hash: 'shared-hash',
        storagePath: 'attachments/shared.txt',
        fileSize: 1,
      );
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'paged-attachment-references',
          'title': 'Paged attachment references',
          'messages': [
            for (var index = 0; index < 45; index++)
              ChatMessage(
                id: 'a$index',
                role: 'user',
                content: 'Message $index',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
                attachments: index == 0 || index == 44
                    ? [sharedAttachment]
                    : const [],
              ).toMap(),
          ],
        }),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      expect(
        container
            .read(conversationsProvider)
            .single
            .messages
            .any((message) => message.id == 'a0'),
        isFalse,
      );

      final referencedPaths = await notifier.getOtherMessageAttachmentPaths(
        'paged-attachment-references',
        'a44',
      );

      expect(referencedPaths, contains('attachments/shared.txt'));
    },
  );

  test(
    'expiry cleanup removes attachments from unloaded repository pages',
    () async {
      final previousPathProvider = PathProviderPlatform.instance;
      final directory = Directory.systemTemp.createTempSync(
        'conversation_cleanup_',
      );
      PathProviderPlatform.instance = _TestPathProvider(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = previousPathProvider;
        directory.deleteSync(recursive: true);
      });

      final attachmentPath = await AttachmentStorage.saveFile(
        'older.txt',
        Uint8List.fromList([1, 2, 3]),
      );
      final expired = Conversation(
        id: 'expired-paged',
        title: 'Expired',
        isTemporary: true,
        temporaryExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        messages: [
          for (var index = 0; index < 35; index++)
            ChatMessage(
              id: 'cleanup-$index',
              role: 'user',
              content: 'message $index',
              createdAt: DateTime.utc(2025, 1, 1).add(Duration(minutes: index)),
              attachments: index == 0
                  ? [
                      Attachment(
                        fileName: 'older.txt',
                        mimeType: 'text/plain',
                        fileType: 'text',
                        hash: AttachmentStorage.computeHash(
                          Uint8List.fromList([1, 2, 3]),
                        ),
                        storagePath: attachmentPath,
                        fileSize: 3,
                      ),
                    ]
                  : const [],
            ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([expired.toMap()]),
        'active_conversation_id': 'expired-paged',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      expect(
        container.read(conversationsProvider).single.messages,
        hasLength(20),
      );

      container.read(conversationsProvider).single.temporaryExpiresAt =
          DateTime.now().subtract(const Duration(minutes: 1));
      await notifier.checkTemporaryExpiryNow();

      expect(await AttachmentStorage.readFile(attachmentPath), isNull);
    },
  );

  test(
    'expiry write failure preserves repository conversation attachments',
    () async {
      final previousPathProvider = PathProviderPlatform.instance;
      final directory = Directory.systemTemp.createTempSync(
        'conversation_expiry_write_failure_',
      );
      PathProviderPlatform.instance = _TestPathProvider(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = previousPathProvider;
        directory.deleteSync(recursive: true);
      });
      final attachmentBytes = Uint8List.fromList([4, 5, 6]);
      final attachmentPath = await AttachmentStorage.saveFile(
        'expiry.txt',
        attachmentBytes,
      );
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'expiry-write-failure',
      });
      final repository = _FailingOrderMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'expiry-write-failure',
          'title': 'Expired with attachment',
          'messages': [
            ChatMessage(
              id: 'expiry-write-failure-message',
              role: 'user',
              content: 'has attachment',
              createdAt: DateTime.utc(2025),
              attachments: [
                Attachment(
                  fileName: 'expiry.txt',
                  mimeType: 'text/plain',
                  fileType: 'text',
                  hash: AttachmentStorage.computeHash(attachmentBytes),
                  storagePath: attachmentPath,
                  fileSize: attachmentBytes.length,
                ),
              ],
            ).toMap(),
          ],
        }),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final conversation = container.read(conversationsProvider).single;
      conversation.isTemporary = true;
      conversation.temporaryExpiresAt = DateTime.now().subtract(
        const Duration(minutes: 1),
      );
      repository.failOrderWrites = true;

      await notifier.checkTemporaryExpiryNow();

      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        contains('expiry-write-failure'),
      );
      expect(await repository.countConversations(), 1);
      expect(await AttachmentStorage.readFile(attachmentPath), attachmentBytes);
    },
  );

  test(
    'failed conversation ordering does not delete repository messages',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FailingOrderMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'order-failure',
          title: 'Keep on failure',
          messages: [_message('preserved-message', 0)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      repository.failOrderWrites = true;

      await notifier.deleteConversation('order-failure');

      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        contains('order-failure'),
      );
      expect(await repository.countConversations(), 1);
      expect(
        (await repository.getMessages('order-failure')).single.id,
        'preserved-message',
      );
    },
  );

  test(
    'batch deletion restores state when repository persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'batch-delete-active',
      });
      final repository = _FailingOrderMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'batch-delete-active',
          title: 'Keep active on failure',
          messages: [_message('batch-active-message', 0)],
        ),
      );
      await repository.importConversation(
        StroomConversation(
          id: 'batch-delete-other',
          title: 'Keep other on failure',
          messages: [_message('batch-other-message', 0)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      expect(container.read(conversationsProvider).length, 2);
      repository.failOrderWrites = true;

      await notifier.batchDelete(['batch-delete-active', 'batch-delete-other']);

      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        containsAll(['batch-delete-active', 'batch-delete-other']),
      );
      expect(
        container.read(activeConversationIdProvider),
        'batch-delete-active',
      );
      expect(await repository.countConversations(), 2);
      expect(
        (await repository.getMessages('batch-delete-active')).single.id,
        'batch-active-message',
      );
      expect(
        (await repository.getMessages('batch-delete-other')).single.id,
        'batch-other-message',
      );
    },
  );

  test(
    'conversation deletion keeps repository rows when reference scan fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FailingMessageReadMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'delete-read-failure',
          title: 'Keep on read failure',
          messages: [_message('unscanned-attachment-message', 0)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      repository.failReads = true;

      await notifier.deleteConversation('delete-read-failure');

      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        contains('delete-read-failure'),
      );
      expect(
        await repository.countMessages(conversationId: 'delete-read-failure'),
        1,
      );
    },
  );

  test(
    'flow deletion keeps repository rows when reference scan fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FailingMessageReadMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'flow-delete-read-failure',
          title: 'Keep flow on read failure',
          messages: [_message('unscanned-flow-attachment-message', 0)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      repository.failReads = true;

      expect(
        await notifier.deleteFlowConversationWithFiles(
          'flow-delete-read-failure',
        ),
        isFalse,
      );
      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        contains('flow-delete-read-failure'),
      );
      expect(
        await repository.countMessages(
          conversationId: 'flow-delete-read-failure',
        ),
        1,
      );
    },
  );

  test(
    'expiry retains repository conversations when attachment scan fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FailingMessageReadMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'expiry-read-failure',
          title: 'Keep on expiry read failure',
          messages: [_message('unscanned-expiry-attachment', 0)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final expiredConversation = container.read(conversationsProvider).single;
      expiredConversation.isTemporary = true;
      expiredConversation.temporaryExpiresAt = DateTime.now().subtract(
        const Duration(minutes: 1),
      );
      repository.failReads = true;

      await notifier.checkTemporaryExpiryNow();

      expect(
        container
            .read(conversationsProvider)
            .map((conversation) => conversation.id),
        contains('expiry-read-failure'),
      );
      expect(await repository.countConversations(), 1);
      expect(
        await repository.countMessages(conversationId: 'expiry-read-failure'),
        1,
      );
    },
  );

  test('expiry rechecks countdown after a pending full-history read', () async {
    SharedPreferences.setMockInitialValues({
      'active_conversation_id': 'expiry-reset-during-read',
    });
    final repository = _DelayedMessageReadMemoryRepository();
    await repository.initialize();
    await repository.importConversation(
      StroomConversation(
        id: 'expiry-reset-during-read',
        title: 'Keep after countdown reset',
        messages: [_message('expiry-reset-message', 0)],
      ),
    );
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await repository.close();
    });
    final notifier = container.read(conversationsProvider.notifier);
    await notifier.ready;
    final conversation = container.read(conversationsProvider).single;
    conversation.isTemporary = true;
    conversation.temporaryExpiresAt = DateTime.now().subtract(
      const Duration(minutes: 1),
    );
    repository.delayNextMessageRead = true;

    final expiry = notifier.checkTemporaryExpiryNow();
    await repository.messageReadStarted.future;
    await notifier.updateMessages(
      'expiry-reset-during-read',
      conversation.messages,
      resetTemporaryCountdown: true,
    );
    repository.releaseMessageRead.complete();
    await expiry;

    expect(
      container.read(conversationsProvider).map((item) => item.id),
      contains('expiry-reset-during-read'),
    );
    expect(await repository.countConversations(), 1);
  });

  test('legacy diagnostics are stored only in bounded redacted form', () {
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'diagnostics-conversation',
      'title': 'Diagnostics',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'updatedAt': '2025-01-01T00:00:00.000Z',
      'messages': [
        {
          'id': 'diagnostics-message',
          'role': 'assistant',
          'content': 'answer',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'rawRequest': {'apiKey': 'secret-value', 'safeField': 'preserved'},
        },
      ],
    });
    final message = conversation.messages.single;
    final legacyExtension =
        message.extensions[ConversationRecordAdapter.legacyMessageNamespace]
            as Map<String, dynamic>;
    final storedRecord = legacyExtension['record'] as Map<String, dynamic>;

    expect(storedRecord, isNot(contains('rawRequest')));
    final restored = ConversationRecordAdapter.messageToLegacyMap(message);
    expect(restored['rawRequest'], {'safeField': 'preserved'});
  });

  test('preserves base64 fields in unknown legacy extension data', () {
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'opaque-extension',
      'title': 'Opaque extension',
      'vendorState': {
        'base64Data': 'opaque-value',
        'nested': [
          {'base64Data': 'another-opaque-value'},
        ],
      },
    });

    final restored = ConversationRecordAdapter.toLegacyMap(
      conversation,
      const [],
    );

    expect(restored['vendorState'], {
      'base64Data': 'opaque-value',
      'nested': [
        {'base64Data': 'another-opaque-value'},
      ],
    });
  });

  test('preserves opaque conversation extension namespace data', () {
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'opaque-conversation-extension',
      'title': 'Opaque extension',
      'vendorState': {'value': 'root'},
      'extensions': {
        'stroom.legacyConversation': {
          'opaqueConversationField': {'value': 'nested'},
        },
        'vendor.example': {'value': 'extension'},
      },
    });

    final restored = ConversationRecordAdapter.toLegacyMap(
      conversation,
      const [],
    );

    expect(restored['vendorState'], {'value': 'root'});
    expect(restored['extensions'], {
      'stroom.legacyConversation': {
        'opaqueConversationField': {'value': 'nested'},
      },
      'vendor.example': {'value': 'extension'},
    });
    expect(restored['vendorState'], {'value': 'root'});
  });

  test('preserves marker-shaped conversation extension maps', () {
    const originalExtension = {
      '_stroomAdapterLegacyConversationOpaqueExtensionValue': 'vendor state',
      'nested': {'keep': true},
    };
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'marker-shaped-conversation-extension',
      'title': 'Marker-shaped conversation extension',
      'extensions': {
        ConversationRecordAdapter.legacyConversationNamespace:
            originalExtension,
      },
    });

    final restored = ConversationRecordAdapter.toLegacyMap(
      conversation,
      const [],
    );

    expect(
      (restored['extensions']
          as Map)[ConversationRecordAdapter.legacyConversationNamespace],
      originalExtension,
    );
  });

  test('preserves non-map conversation extension namespace payloads', () {
    const opaqueValue = [
      'vendor-state',
      42,
      {'enabled': true},
    ];
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'opaque-conversation-extension-value',
      'title': 'Opaque conversation extension value',
      'extensions': {
        'stroom.legacyConversation': opaqueValue,
        'vendor.example': {'value': 'extension'},
      },
    });

    final restored = ConversationRecordAdapter.toLegacyMap(
      conversation,
      const [],
    );

    expect(
      (restored['extensions'] as Map)['stroom.legacyConversation'],
      opaqueValue,
    );
    expect((restored['extensions'] as Map)['vendor.example'], {
      'value': 'extension',
    });
  });

  test(
    'legacy adapter round trips neutral message fields without a record',
    () {
      final original = StroomMessage(
        id: 'neutral-message',
        role: 'assistant',
        sequence: 4,
        createdAt: DateTime.utc(2025, 1, 1),
        content: [StroomContentPart.text('neutral text')],
        status: 'completed',
        finishReason: 'stop',
        usage: const {'input_tokens': 12, 'output_tokens': 3},
        extensions: const {
          'vendor.example.message': {'trace': 'opaque'},
        },
      );

      final legacy = ChatMessage.fromMap(
        ConversationRecordAdapter.messageToLegacyMap(original),
      );
      final restored = StroomMessage.fromLegacy(legacy, sequence: 4);

      expect(restored.status, 'completed');
      expect(restored.finishReason, 'stop');
      expect(restored.usage, {'input_tokens': 12, 'output_tokens': 3});
      expect(restored.extensions['vendor.example.message'], {
        'trace': 'opaque',
      });
    },
  );

  test('legacy adapter preserves non-map opaque legacy extension payloads', () {
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'opaque-extension-payload',
      'title': 'Opaque extension payload',
      'messages': [
        {
          'id': 'opaque-extension-message',
          'role': 'user',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'content': 'message',
          'extensions': {
            'stroom.legacy': ['opaque', 'payload'],
          },
        },
      ],
    });

    final restored = ConversationRecordAdapter.messageToLegacyMap(
      conversation.messages.single,
    );
    expect((restored['extensions'] as Map)['stroom.legacy'], [
      'opaque',
      'payload',
    ]);
  });

  test('legacy adapter preserves marker-shaped opaque extension maps', () {
    final originalExtension = {
      'opaqueExtensionValue': 'vendor payload',
      'nested': {'keep': true},
    };
    final legacyMessage = ChatMessage.fromMap({
      'id': 'marker-shaped-extension',
      'role': 'user',
      'createdAt': '2025-01-01T00:00:00.000Z',
      'content': 'message',
      'extensions': {
        'stroom.legacy': originalExtension,
        'vendor.example': {'trace': 'opaque'},
      },
    });
    final neutralMessage = StroomMessage.fromLegacy(legacyMessage, sequence: 0);

    final restored = ConversationRecordAdapter.messageToLegacyMap(
      neutralMessage,
    );

    expect(restored['extensions'], {
      'stroom.legacy': originalExtension,
      'vendor.example': {'trace': 'opaque'},
    });
  });

  test('migration preserves open-ended legacy message roles', () {
    final conversation = ConversationRecordAdapter.fromLegacyMap({
      'id': 'open-ended-roles',
      'title': 'Open-ended roles',
      'messages': [
        for (final role in ['system', 'developer', 'tool'])
          {
            'id': 'message-$role',
            'role': role,
            'createdAt': '2025-01-01T00:00:00.000Z',
            'content': '$role content',
          },
      ],
    });

    expect(conversation.messages.map((message) => message.role), [
      'system',
      'developer',
      'tool',
    ]);
    expect(
      conversation.messages.map(
        (message) =>
            ConversationRecordAdapter.messageToLegacyMap(message)['role'],
      ),
      ['system', 'developer', 'tool'],
    );
  });

  test('canonical message fields replace retained legacy record values', () {
    final message = StroomMessage(
      id: 'message-current',
      role: 'assistant',
      sequence: 4,
      createdAt: DateTime.utc(2025, 1, 2),
      content: [StroomContentPart.text('current text')],
      status: 'completed',
      finishReason: 'stop',
      usage: const {'input_tokens': 20},
      extensions: const {
        'vendor.example.message': {'trace': 'current'},
        'stroom.legacy': {
          'record': {
            'id': 'message-old',
            'role': 'user',
            'createdAt': '2020-01-01T00:00:00.000Z',
            'content': 'old text',
            'status': 'pending',
            'finishReason': 'length',
            'usage': {'input_tokens': 1},
            'extensions': {
              'vendor.example.message': {'trace': 'old'},
            },
            'opaqueRecordField': 'preserved',
          },
        },
      },
      extraFields: const {'opaqueNewField': 'also preserved'},
    );

    final legacy = ConversationRecordAdapter.messageToLegacyMap(message);

    expect(legacy['id'], 'message-current');
    expect(legacy['role'], 'assistant');
    expect(legacy['createdAt'], '2025-01-02T00:00:00.000Z');
    expect(legacy['content'], 'current text');
    expect(legacy['status'], 'completed');
    expect(legacy['finishReason'], 'stop');
    expect(legacy['usage'], {'input_tokens': 20});
    expect(legacy['extensions'], {
      'vendor.example.message': {'trace': 'current'},
    });
    expect(legacy['opaqueRecordField'], 'preserved');
    expect(legacy['opaqueNewField'], 'also preserved');
  });
}

StroomMessage _message(String id, int sequence, [String text = 'text']) =>
    StroomMessage(
      id: id,
      role: 'user',
      sequence: sequence,
      createdAt: DateTime.utc(2025, 1, 1, 0, sequence),
      content: [StroomContentPart.text(text)],
    );

String _legacyConversation(String id, List<String> messageIds) =>
    '{"id":"$id","title":"$id","createdAt":"2025-01-01T00:00:00.000Z",'
    '"updatedAt":"2025-01-02T00:00:00.000Z","messages":['
    '${messageIds.map((messageId) => '{"id":"$messageId","role":"user",'
        '"content":"$messageId","createdAt":"2025-01-01T00:00:00.000Z"}').join(',')}]}';
