// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';

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
    _subscription = container.listen(conversationsProvider, (_, next) {
      if (next.isEmpty) {
        _sawRemoval = true;
      } else if (_sawRemoval && !restored.isCompleted) {
        restored.complete();
      }
    });
  }

  final Completer<void> restored = Completer<void>();
  late final ProviderSubscription<List<Conversation>> _subscription;
  bool _sawRemoval = false;

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
          notifier.state = [_conversation()];
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

Future<void> _deleteBySelectionMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.checklist));
  await _pumpUi(tester);
  await tester.tap(find.byType(Checkbox).first);
  await _pumpUi(tester);
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
    'conversations page continues file cleanup after one attachment fails',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('stroom_delete_test_');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.deleteSync(recursive: true));
      final attemptedPaths = <String>[];
      final cleanupComplete = Completer<void>();
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        attemptedPaths.add(path);
        if (path == 'attachments/file.txt') throw FileSystemException('failed');
        if (!cleanupComplete.isCompleted) cleanupComplete.complete();
        return true;
      };
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await _pumpUi(tester);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await _pumpUi(tester);
      await tester.tap(find.text('Delete').last);
      await _pumpUi(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await _awaitSignal(tester, cleanupComplete);
      await _pumpUi(tester);

      expect(attemptedPaths, [
        'attachments/file.txt',
        'attachments/second.txt',
      ]);
      expect(find.text('Delete test'), findsNothing);
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
