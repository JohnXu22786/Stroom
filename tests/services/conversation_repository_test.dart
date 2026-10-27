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
import 'package:stroom/services/conversation_repository_memory.dart';

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
  Future<void> setConversationOrder(List<String> conversationIds) async {
    if (failOrderWrites) throw StateError('simulated order write failure');
    await super.setConversationOrder(conversationIds);
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
        final raw = '[${_legacyConversation('c1', ['m1', 'm2'])},'
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
          ))
              .map((message) => message.id),
          ['m1', 'm2'],
        );
        await resetRepository.close();
        await repository.close();
      },
    );

    test('reconciles stale rows when the legacy source changes', () async {
      final preferences = await SharedPreferences.getInstance();
      final originalConversation = Map<String, dynamic>.from(
        jsonDecode(_legacyConversation('stale', ['old'])) as Map,
      )..['draftAttachments'] = [
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

      final replacementConversation = Map<String, dynamic>.from(
        jsonDecode(_legacyConversation('replacement', ['new'])) as Map,
      )..['draftAttachments'] = [
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
      final attachmentManifest = jsonDecode(
        preferences.getString(
          ConversationMigrationService.attachmentManifestBackupKey,
        )!,
      ) as List;
      expect(attachmentManifest, hasLength(1));
      expect(attachmentManifest.single['storagePath'],
          'https://media.example/replacement.png');
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
        final manifest = jsonDecode(
          preferences.getString(
            ConversationMigrationService.attachmentManifestBackupKey,
          )!,
        ) as List;
        expect(manifest.single, isNot(contains('base64Data')));
        await repository.close();
      },
    );
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
