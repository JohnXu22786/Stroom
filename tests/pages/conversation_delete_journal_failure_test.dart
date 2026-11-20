// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/storage_service.dart';

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _GatedDocumentsPathProvider extends PathProviderPlatform {
  _GatedDocumentsPathProvider(this.path);

  final Future<String?> path;

  @override
  Future<String?> getApplicationDocumentsPath() => path;
}

class _RollbackObserver {
  _RollbackObserver(ProviderContainer container) {
    _previousLength = container.read(conversationsProvider).length;
    _subscription = container.listen(conversationsProvider, (_, next) {
      if (next.length < _previousLength) {
        _sawRemoval = true;
      } else if (_sawRemoval &&
          next.length > _previousLength &&
          !restored.isCompleted) {
        restored.complete();
      }
      _previousLength = next.length;
    });
  }

  final Completer<void> restored = Completer<void>();
  late final ProviderSubscription<List<Conversation>> _subscription;
  bool _sawRemoval = false;
  late int _previousLength;

  void close() => _subscription.close();
}

const _journalName = 'conversation_stream_checkpoints.jsonl';

Conversation _conversation() => Conversation(
      id: 'delete-test',
      title: 'Delete test',
      assistantId: 'assistant',
      messages: [
        ChatMessage(
          id: 'message',
          role: 'user',
          content: 'attached',
          attachments: [
            Attachment(
              id: 'attachment',
              fileName: 'file.txt',
              mimeType: 'text/plain',
              fileType: 'file',
              hash: 'hash',
              storagePath: 'attachments/file.txt',
              fileSize: 4,
            ),
            Attachment(
              id: 'attachment-2',
              fileName: 'second.txt',
              mimeType: 'text/plain',
              fileType: 'file',
              hash: 'hash-2',
              storagePath: 'attachments/second.txt',
              fileSize: 6,
            ),
          ],
        ),
      ],
    );

Conversation _conversationSharingFile({
  required String id,
  required String storagePath,
}) =>
    Conversation(
      id: id,
      title: 'Delete test shared',
      assistantId: 'assistant',
      messages: [
        ChatMessage(
          id: 'shared-message',
          role: 'user',
          content: 'attached',
          attachments: [
            Attachment(
              id: 'shared-attachment',
              fileName: 'file.txt',
              mimeType: 'text/plain',
              fileType: 'file',
              hash: 'hash',
              storagePath: storagePath,
              fileSize: 4,
            ),
          ],
        ),
      ],
    );

Directory _blockConversationJournal() {
  final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
  PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
  AppStorage.resetCache();
  Directory(p.join(root.path, _journalName)).createSync();
  AttachmentStorage.deleteFileOverrideForTesting = (_) async => true;
  return root;
}

Widget _app({
  required Widget home,
  List<Conversation>? conversations,
}) =>
    ProviderScope(
      overrides: [
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = [
            Assistant(
              id: 'assistant',
              name: 'Assistant',
              prompt: 'Prompt',
              emoji: '🤖',
            ),
          ];
          return notifier;
        }),
        selectedAssistantIdProvider.overrideWith((ref) => 'assistant'),
        conversationsInitialLoadProvider.overrideWith((ref) async {}),
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = conversations ?? [_conversation()];
          return notifier;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

Future<void> _pumpUi(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _awaitSignal(WidgetTester tester, Completer<void> signal) async {
  for (var attempt = 0; attempt < 50 && !signal.isCompleted; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(signal.isCompleted, isTrue, reason: 'async operation did not finish');
}

Future<void> _deleteBySelectionMode(
  WidgetTester tester, {
  int? selectCount,
}) async {
  await tester.tap(find.byIcon(Icons.checklist));
  await _pumpUi(tester);
  final checkboxCount = find.byType(Checkbox).evaluate().length;
  for (var index = 0; index < (selectCount ?? checkboxCount); index++) {
    await tester.tap(find.byType(Checkbox).at(index));
    await _pumpUi(tester);
  }
  await tester.tap(find.byIcon(Icons.delete).first);
  await _pumpUi(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPathProvider;

  setUp(() {
    originalPathProvider = PathProviderPlatform.instance;
    SharedPreferences.setMockInitialValues({});
    AttachmentStorage.resetOverridesForTesting();
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    AttachmentStorage.resetOverridesForTesting();
  });

  testWidgets(
    'topic selection keeps attachments when the delete journal write fails',
    (tester) async {
      final root = _blockConversationJournal();
      addTearDown(() => root.deleteSync(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };
      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(TopicSelectionPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversations page keeps attachments when the delete journal write fails',
    (tester) async {
      final root = _blockConversationJournal();
      addTearDown(() => root.deleteSync(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(ConversationsPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversation file cleanup finishes if its page is disposed during a read',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.deleteSync(recursive: true));
      final readStarted = Completer<void>();
      final allowRead = Completer<void>();
      final deletedPaths = <String>[];
      AttachmentStorage.readFileOverrideForTesting = (path) async {
        if (!readStarted.isCompleted) readStarted.complete();
        await allowRead.future;
        return Uint8List.fromList([1, 2, 3]);
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await _awaitSignal(tester, readStarted);

      await tester.pumpWidget(const SizedBox.shrink());
      allowRead.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(deletedPaths, ['attachments/file.txt']);
    },
  );

  testWidgets(
    'single delete preserves a late shared attachment and restores on cleanup failure',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.deleteSync(recursive: true));
      final attemptedPaths = <String>[];
      final restoredPaths = <String>[];
      final cleanupComplete = Completer<void>();
      AttachmentStorage.readFileOverrideForTesting =
          (_) async => Uint8List.fromList([1, 2, 3]);
      AttachmentStorage.restoreFileOverrideForTesting = (path, _) async {
        restoredPaths.add(path);
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        attemptedPaths.add(path);
        if (path == 'attachments/second.txt') {
          if (!cleanupComplete.isCompleted) cleanupComplete.complete();
          throw FileSystemException('failed');
        }
        if (!cleanupComplete.isCompleted) cleanupComplete.complete();
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(ConversationsPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConversationsPage)),
        listen: false,
      );
      container.read(conversationsProvider.notifier).state = [
        _conversation(),
        _conversationSharingFile(
          id: 'delete-test-retained',
          storagePath: 'temp_edited/file.txt',
        ),
      ];
      container.read(activeConversationIdProvider.notifier).state =
          'delete-test';
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await _awaitSignal(tester, cleanupComplete);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(attemptedPaths, ['attachments/second.txt']);
      expect(restoredPaths, ['attachments/second.txt']);
      expect(find.text('Delete test'), findsOneWidget);
      expect(find.text('Delete test shared'), findsOneWidget);
      expect(
        container.read(conversationsProvider).map((conv) => conv.id).toSet(),
        {'delete-test', 'delete-test-retained'},
      );
      expect(container.read(activeConversationIdProvider), 'delete-test');

      await tester.pumpWidget(const SizedBox.shrink());
      final replayConversation = _conversation()
        ..draftAttachments = [
          Attachment(
            id: 'draft-attachment',
            fileName: 'draft.png',
            mimeType: 'image/png',
            fileType: 'image',
            hash: 'draft-hash',
            storagePath: 'attachments/draft.png',
            fileSize: 3,
            base64Data: 'AQID',
          ),
        ];
      final deletedAt = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conversations', '[]');
      await prefs.setBool('conversation_stream_checkpoints_present', true);
      await prefs.remove('conversation_stream_pending_restores');
      await File(p.join(root.path, _journalName)).writeAsString(
        [
          {
            'kind': 'conversationDeleted',
            'conversationId': replayConversation.id,
            'deletedAt': deletedAt,
          },
          {
            'kind': 'conversationRestored',
            'conversationId': replayConversation.id,
            'conversation': replayConversation.toMap(),
            'index': 0,
          },
        ].map(jsonEncode).join('\n'),
      );
      final replayContainer = ProviderContainer();
      addTearDown(replayContainer.dispose);
      await replayContainer.read(conversationsProvider.notifier).ready;
      expect(
        replayContainer
            .read(conversationsProvider)
            .single
            .draftAttachments
            .single
            .base64Data,
        'AQID',
      );

      await prefs.setString('conversations', '[]');
      final fallbackRestoredAt = DateTime.now().add(const Duration(seconds: 1));
      await prefs.setString(
        'conversation_stream_pending_restore_snapshots',
        jsonEncode({
          replayConversation.id: {
            'conversation': replayConversation.toMap(),
            'index': 0,
            'restoredAt': fallbackRestoredAt.toIso8601String(),
          },
        }),
      );
      await File(p.join(root.path, _journalName)).writeAsString(
        jsonEncode({
          'kind': 'conversationDeleted',
          'conversationId': replayConversation.id,
          'deletedAt': deletedAt,
        }),
      );
      final fallbackContainer = ProviderContainer();
      addTearDown(fallbackContainer.dispose);
      await fallbackContainer.read(conversationsProvider.notifier).ready;
      expect(
        fallbackContainer
            .read(conversationsProvider)
            .single
            .draftAttachments
            .single
            .base64Data,
        'AQID',
      );
      final newerSelection = _conversationSharingFile(
        id: 'delete-test-new-active',
        storagePath: 'attachments/new-active.txt',
      );
      fallbackContainer.read(conversationsProvider.notifier).state = [
        newerSelection,
      ];
      fallbackContainer.read(activeConversationIdProvider.notifier).state =
          newerSelection.id;
      await fallbackContainer
          .read(conversationsProvider.notifier)
          .restoreDeletedConversations(
        [replayConversation],
        originalOrder: [replayConversation, newerSelection],
        previousActiveConversationId: replayConversation.id,
      );
      expect(
        fallbackContainer.read(activeConversationIdProvider),
        newerSelection.id,
      );

      await prefs.setString('conversations', '[]');
      await prefs.setBool('conversation_stream_checkpoints_present', true);
      await prefs.setString(
        'conversation_stream_pending_restore_snapshots',
        jsonEncode({
          replayConversation.id: {
            'conversation': replayConversation.toMap(),
            'index': 0,
            'restoredAt': fallbackRestoredAt.toIso8601String(),
          },
        }),
      );
      await File(p.join(root.path, _journalName)).writeAsString(
        jsonEncode({
          'kind': 'conversationDeleted',
          'conversationId': replayConversation.id,
          'deletedAt': fallbackRestoredAt.toIso8601String(),
        }),
      );
      final laterDeleteContainer = ProviderContainer();
      addTearDown(laterDeleteContainer.dispose);
      await laterDeleteContainer.read(conversationsProvider.notifier).ready;
      expect(laterDeleteContainer.read(conversationsProvider), isEmpty);

      await prefs.setString('conversations', '[]');
      await prefs.setBool('conversation_stream_checkpoints_present', false);
      await prefs.setString(
        'conversation_stream_pending_restore_snapshots',
        jsonEncode({
          replayConversation.id: {
            'conversation': replayConversation.toMap(),
            'index': 0,
            'restoredAt': fallbackRestoredAt.toIso8601String(),
            'supersededAt': DateTime.now().toIso8601String(),
          },
        }),
      );
      await File(p.join(root.path, _journalName)).writeAsString('');
      final supersededContainer = ProviderContainer();
      addTearDown(supersededContainer.dispose);
      await supersededContainer.read(conversationsProvider.notifier).ready;
      expect(supersededContainer.read(conversationsProvider), isEmpty);

      await prefs.setString('conversations', '[]');
      await prefs.setBool('conversation_stream_checkpoints_present', true);
      final newerJournalConversation = Conversation.fromMap(
        replayConversation.toMap(),
      )..title = 'Journal restoration is newer';
      await prefs.setString(
        'conversation_stream_pending_restore_snapshots',
        jsonEncode({
          replayConversation.id: {
            'conversation': replayConversation.toMap(),
            'index': 0,
            'restoredAt': fallbackRestoredAt.toIso8601String(),
          },
        }),
      );
      await File(p.join(root.path, _journalName)).writeAsString(
        [
          {
            'kind': 'conversationRestored',
            'conversationId': newerJournalConversation.id,
            'conversation': newerJournalConversation.toMap(),
            'index': 0,
            'restoredAt': fallbackRestoredAt
                .add(const Duration(seconds: 1))
                .toIso8601String(),
          },
        ].map(jsonEncode).join('\n'),
      );
      final newerRestoreContainer = ProviderContainer();
      addTearDown(newerRestoreContainer.dispose);
      await newerRestoreContainer.read(conversationsProvider.notifier).ready;
      expect(
        newerRestoreContainer.read(conversationsProvider).single.title,
        'Journal restoration is newer',
      );
    },
  );

  testWidgets(
    'batch conversation delete keeps the conversation when attachment cleanup fails',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.deleteSync(recursive: true));
      final restoredPaths = <String>[];
      final attemptedPaths = <String>[];
      AttachmentStorage.readFileOverrideForTesting =
          (_) async => Uint8List.fromList([1, 2, 3]);
      AttachmentStorage.restoreFileOverrideForTesting = (path, _) async {
        restoredPaths.add(path);
      };
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        attemptedPaths.add(path);
        if (path == 'attachments/second.txt') {
          throw FileSystemException('failed');
        }
        return true;
      };
      await tester.pumpWidget(
        _app(
          home: const TopicSelectionPage(),
          conversations: [
            _conversation(),
            _conversationSharingFile(
              id: 'delete-test-shared',
              storagePath: 'attachments/file.txt',
            ),
            _conversationSharingFile(
              id: 'delete-test-retained',
              storagePath: 'temp_edited/file.txt',
            ),
          ],
        ),
      );
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(TopicSelectionPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TopicSelectionPage)),
        listen: false,
      );
      container.read(activeConversationIdProvider.notifier).state =
          'delete-test';
      await _deleteBySelectionMode(tester, selectCount: 2);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(find.text('Delete test'), findsOneWidget);
      expect(find.text('Delete test shared'), findsNWidgets(2));
      expect(
        container.read(conversationsProvider).map((conv) => conv.id).toSet(),
        {'delete-test', 'delete-test-shared', 'delete-test-retained'},
      );
      expect(container.read(activeConversationIdProvider), 'delete-test');
      expect(attemptedPaths, ['attachments/second.txt']);
      expect(restoredPaths, ['attachments/second.txt']);
    },
  );

  testWidgets(
    'conversation deletion still cleans files if the page is disposed',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
      final documentsPath = Completer<String?>();
      PathProviderPlatform.instance =
          _GatedDocumentsPathProvider(documentsPath.future);
      AppStorage.resetCache();
      addTearDown(() => root.deleteSync(recursive: true));
      final deletedPaths = <String>[];
      final cleanupComplete = Completer<void>();
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        if (deletedPaths.length == 2 && !cleanupComplete.isCompleted) {
          cleanupComplete.complete();
        }
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      documentsPath.complete(root.path);
      await _awaitSignal(tester, cleanupComplete);
      await _pumpUi(tester);

      expect(tester.takeException(), isNull);
      expect(deletedPaths, ['attachments/file.txt', 'attachments/second.txt']);
    },
  );

  testWidgets(
    'topic selection batch delete keeps attachments when journal write fails',
    (tester) async {
      final root = _blockConversationJournal();
      addTearDown(() => root.deleteSync(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };
      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(TopicSelectionPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      await _deleteBySelectionMode(tester);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversations batch delete keeps attachments when journal write fails',
    (tester) async {
      final root = _blockConversationJournal();
      addTearDown(() => root.deleteSync(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      final rollback = _RollbackObserver(
        ProviderScope.containerOf(
          tester.element(find.byType(ConversationsPage)),
          listen: false,
        ),
      );
      addTearDown(rollback.close);
      await _deleteBySelectionMode(tester);
      await _awaitSignal(tester, rollback.restored);
      await _pumpUi(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );
}
