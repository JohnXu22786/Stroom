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
  print('TRACE 76 before');
  final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
  print('TRACE 76 after');
  PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
  AppStorage.resetCache();
  print('TRACE 79 before');
  await Directory(p.join(root.path, _journalName)).create();
  print('TRACE 79 after');
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
  for (var frame = 0; frame < 3; frame++) {
    print('TRACE 116 before');
    await tester.pump(const Duration(milliseconds: 100));
    print('TRACE 116 after');
  }
}

Future<void> _deleteBySelectionMode(WidgetTester tester) async {
  print('TRACE 121 before');
  await tester.tap(find.byIcon(Icons.checklist));
  print('TRACE 121 after');
  print('TRACE 122 before');
  await _pumpUi(tester);
  print('TRACE 122 after');
  print('TRACE 123 before');
  await tester.tap(find.byType(Checkbox).first);
  print('TRACE 123 after');
  print('TRACE 124 before');
  await _pumpUi(tester);
  print('TRACE 124 after');
  print('TRACE 125 before');
  await tester.tap(find.byIcon(Icons.delete).first);
  print('TRACE 125 after');
  print('TRACE 126 before');
  await _pumpUi(tester);
  print('TRACE 126 after');
  print('TRACE 127 before');
  await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
  print('TRACE 127 after');
  print('TRACE 128 before');
  await _pumpUi(tester);
  print('TRACE 128 after');
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
      print('TRACE 151 before');
      final root = await _blockConversationJournal();
      print('TRACE 151 after');
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      print('TRACE 159 before');
      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      print('TRACE 159 after');
      print('TRACE 160 before');
      await _pumpUi(tester);
      print('TRACE 160 after');
      print('TRACE 161 before');
      await tester.tap(find.byIcon(Icons.more_vert).first);
      print('TRACE 161 after');
      print('TRACE 162 before');
      await _pumpUi(tester);
      print('TRACE 162 after');
      print('TRACE 163 before');
      await tester.tap(find.text('Delete').last);
      print('TRACE 163 after');
      print('TRACE 164 before');
      await _pumpUi(tester);
      print('TRACE 164 after');
      print('TRACE 165 before');
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      print('TRACE 165 after');
      print('TRACE 166 before');
      await _pumpUi(tester);
      print('TRACE 166 after');

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'conversations page keeps attachments when the delete journal write fails',
    (tester) async {
      print('TRACE 176 before');
      final root = await _blockConversationJournal();
      print('TRACE 176 after');
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      print('TRACE 184 before');
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      print('TRACE 184 after');
      print('TRACE 185 before');
      await _pumpUi(tester);
      print('TRACE 185 after');
      print('TRACE 186 before');
      await tester.tap(find.byIcon(Icons.more_vert).first);
      print('TRACE 186 after');
      print('TRACE 187 before');
      await _pumpUi(tester);
      print('TRACE 187 after');
      print('TRACE 188 before');
      await tester.tap(find.text('Delete').last);
      print('TRACE 188 after');
      print('TRACE 189 before');
      await _pumpUi(tester);
      print('TRACE 189 after');
      print('TRACE 190 before');
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      print('TRACE 190 after');
      print('TRACE 191 before');
      await _pumpUi(tester);
      print('TRACE 191 after');

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'conversations page continues file cleanup after one attachment fails',
    (tester) async {
      print('TRACE 201 before');
      final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
      print('TRACE 201 after');
      PathProviderPlatform.instance = _DocumentsPathProvider(root.path);
      AppStorage.resetCache();
      addTearDown(() => root.delete(recursive: true));
      final attemptedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        attemptedPaths.add(path);
        if (path == 'attachments/file.txt') throw FileSystemException('failed');
        return true;
      };

      print('TRACE 212 before');
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      print('TRACE 212 after');
      print('TRACE 213 before');
      await _pumpUi(tester);
      print('TRACE 213 after');
      print('TRACE 214 before');
      await tester.tap(find.byIcon(Icons.more_vert).first);
      print('TRACE 214 after');
      print('TRACE 215 before');
      await _pumpUi(tester);
      print('TRACE 215 after');
      print('TRACE 216 before');
      await tester.tap(find.text('Delete').last);
      print('TRACE 216 after');
      print('TRACE 217 before');
      await _pumpUi(tester);
      print('TRACE 217 after');
      print('TRACE 218 before');
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      print('TRACE 218 after');
      print('TRACE 219 before');
      await _pumpUi(tester);
      print('TRACE 219 after');

      expect(attemptedPaths, [
        'attachments/file.txt',
        'attachments/second.txt',
      ]);
      expect(find.text('Delete test'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'conversation deletion still cleans files if the page is disposed',
    (tester) async {
      print('TRACE 232 before');
      final root = await Directory.systemTemp.createTemp('stroom_delete_test_');
      print('TRACE 232 after');
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

      print('TRACE 244 before');
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      print('TRACE 244 after');
      print('TRACE 245 before');
      await _pumpUi(tester);
      print('TRACE 245 after');
      print('TRACE 246 before');
      await tester.tap(find.byIcon(Icons.more_vert).first);
      print('TRACE 246 after');
      print('TRACE 247 before');
      await _pumpUi(tester);
      print('TRACE 247 after');
      print('TRACE 248 before');
      await tester.tap(find.text('Delete').last);
      print('TRACE 248 after');
      print('TRACE 249 before');
      await _pumpUi(tester);
      print('TRACE 249 after');
      print('TRACE 250 before');
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      print('TRACE 250 after');
      print('TRACE 251 before');
      await tester.pump();
      print('TRACE 251 after');

      print('TRACE 253 before');
      await tester.pumpWidget(const SizedBox.shrink());
      print('TRACE 253 after');
      documentsPath.complete(root.path);
      print('TRACE 255 before');
      await _pumpUi(tester);
      print('TRACE 255 after');

      expect(tester.takeException(), isNull);
      expect(deletedPaths, ['attachments/file.txt', 'attachments/second.txt']);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'topic selection batch delete keeps attachments when journal write fails',
    (tester) async {
      print('TRACE 265 before');
      final root = await _blockConversationJournal();
      print('TRACE 265 after');
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      print('TRACE 273 before');
      await tester.pumpWidget(_app(home: const TopicSelectionPage()));
      print('TRACE 273 after');
      print('TRACE 274 before');
      await _pumpUi(tester);
      print('TRACE 274 after');
      print('TRACE 275 before');
      await _deleteBySelectionMode(tester);
      print('TRACE 275 after');

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'conversations batch delete keeps attachments when journal write fails',
    (tester) async {
      print('TRACE 285 before');
      final root = await _blockConversationJournal();
      print('TRACE 285 after');
      addTearDown(() => root.delete(recursive: true));
      final deletedPaths = <String>[];
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        deletedPaths.add(path);
        return true;
      };

      print('TRACE 293 before');
      await tester.pumpWidget(_app(home: const ConversationsPage()));
      print('TRACE 293 after');
      print('TRACE 294 before');
      await _pumpUi(tester);
      print('TRACE 294 after');
      print('TRACE 295 before');
      await _deleteBySelectionMode(tester);
      print('TRACE 295 after');

      expect(deletedPaths, isEmpty);
      expect(find.text('Delete test'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
