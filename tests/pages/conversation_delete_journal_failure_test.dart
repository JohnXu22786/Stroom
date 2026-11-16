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

Future<Directory> _blockConversationJournal() async {
  final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
  PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
  AppStorage.resetCache();
  await Directory(p.join(root.path, _journalName)).create();
  AttachmentStorage.deleteFileOverrideForTesting = (_) async => true;
  return root;
}

Widget _app({required Widget home}) => ProviderScope(
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

Future<void> _deleteBySelectionMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.checklist));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.delete).first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
  await tester.pumpAndSettle();
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
      final root = await _blockConversationJournal();
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversations page keeps attachments when the delete journal write fails',
    (tester) async {
      final root = await _blockConversationJournal();
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversations page continues file cleanup after one attachment fails',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.delete(recursive: true));
      final attemptedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        attemptedPaths.add(path);
        if (path == 'attachments/file.txt') throw FileSystemException('failed');
        return true;
      };

      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

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
      final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
      final documentsPath = Completer<String?>();
      PathProviderPlatform.instance =
          _GatedDocumentsPathProvider(documentsPath.future);
      AppStorage.resetCache();
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      documentsPath.complete(root.path);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(deletedPaths, ['attachments/file.txt', 'attachments/second.txt']);
    },
  );

  testWidgets(
    'topic selection batch delete keeps attachments when journal write fails',
    (tester) async {
      final root = await _blockConversationJournal();
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      await tester.pumpAndSettle();
      await _deleteBySelectionMode(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  testWidgets(
    'conversations batch delete keeps attachments when journal write fails',
    (tester) async {
      final root = await _blockConversationJournal();
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      await tester.pumpWidget(_app(home: const ConversationsPage()));
      await tester.pumpAndSettle();
      await _deleteBySelectionMode(tester);

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
  );
}
