// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/attachment_storage.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

void main() {
  late Directory root;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousPathProvider = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('composer_edit_race');
    PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
    await Directory('${root.path}/tmp').create(recursive: true);
    await Directory('${root.path}/attachments').create(recursive: true);
    AttachmentStorage.resetOverridesForTesting();
  });

  tearDown(() async {
    AttachmentStorage.resetOverridesForTesting();
    PathProviderPlatform.instance = previousPathProvider;
    await root.delete(recursive: true);
  });

  late GlobalKey<ChatComposerWidgetState> composerKey;
  List<Attachment>? sent;

  Future<void> mountComposer(
    WidgetTester tester, {
    Attachment? editingAttachment,
  }) async {
    composerKey = GlobalKey<ChatComposerWidgetState>();
    sent = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(
            (ref) => ConversationsNotifier(ref),
          ),
          activeConversationIdProvider.overrideWith((ref) => 'race-test'),
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ChatComposerWidget(
              key: composerKey,
              conversationId: 'race-test',
              editingMessageId:
                  editingAttachment == null ? null : 'message-to-edit',
              editingMessageText:
                  editingAttachment == null ? null : 'message text',
              editingMessageAttachments:
                  editingAttachment == null ? null : [editingAttachment],
              initialDraftAttachments: const [],
              onSend: (text, attachments) => sent = attachments,
              onStop: () {},
              onEnabledToolsChanged: (_) {},
              onModelSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<Attachment> addImage(WidgetTester tester, String id) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    await tester.runAsync(
      () => composerKey.currentState!.addPendingAttachmentForTesting(
        '$id.png',
        bytes,
      ),
    );
    return composerKey.currentState!.pendingAttachmentsForTesting.singleWhere(
      (attachment) => attachment.fileName == '$id.png',
    );
  }

  Future<void> removeFile(String storagePath) async {
    final name = storagePath.split('/').last;
    final file = File('${root.path}/attachments/$name');
    if (await file.exists()) await file.delete();
  }

  testWidgets(
    'removing an attachment during old-file cleanup removes the saved edit',
    (tester) async {
      await mountComposer(tester);
      final editedOriginal = await addImage(tester, 'edited');
      final otherOriginal = await addImage(tester, 'other');
      final cleanupStarted = Completer<void>();
      final finishCleanup = Completer<void>();
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        if (path == editedOriginal.storagePath) {
          if (!cleanupStarted.isCompleted) cleanupStarted.complete();
          await finishCleanup.future;
        }
        await removeFile(path);
        return true;
      };

      final edit = composerKey.currentState!
          .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
      await tester.runAsync(() => cleanupStarted.future);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('pending_att_${editedOriginal.id}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      finishCleanup.complete();
      await tester.runAsync(() => edit);

      final files = await Directory('${root.path}/attachments').list().toList();
      expect(
        files,
        hasLength(1),
        reason: 'removal must clean up the saved edit file',
      );
      expect(
        files.single.path,
        endsWith(otherOriginal.storagePath.split('/').last),
      );
    },
  );

  testWidgets(
    'reordering during old-file cleanup keeps the edited file referenced',
    (tester) async {
      await mountComposer(tester);
      final editedOriginal = await addImage(tester, 'edited');
      final otherOriginal = await addImage(tester, 'other');
      final cleanupStarted = Completer<void>();
      final finishCleanup = Completer<void>();
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        if (path == editedOriginal.storagePath) {
          if (!cleanupStarted.isCompleted) cleanupStarted.complete();
          await finishCleanup.future;
        }
        await removeFile(path);
        return true;
      };

      final edit = composerKey.currentState!
          .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
      await tester.runAsync(() => cleanupStarted.future);
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(ValueKey('pending_att_${editedOriginal.id}')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveBy(const Offset(170, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      finishCleanup.complete();
      await tester.runAsync(() => edit);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent?.map((att) => att.id).toList(), [
        otherOriginal.id,
        editedOriginal.id,
      ]);
      final edited = sent!.last;
      expect(edited.storagePath, startsWith('temp_edited/'));
      expect(await AttachmentStorage.readFile(edited.storagePath), editedBytes);
    },
  );

  testWidgets(
    'removing edited replacements deletes them and preserves original source',
    (tester) async {
      final sourceBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      final sourcePath = await tester.runAsync(
        () => AttachmentStorage.saveFile('source.png', sourceBytes),
      );
      final source = Attachment(
        id: 'source-image',
        fileName: 'source.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'source-hash',
        storagePath: sourcePath!,
        fileSize: sourceBytes.length,
        base64Data: base64Encode(sourceBytes),
      );
      await mountComposer(tester, editingAttachment: source);
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );

      await tester.runAsync(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes),
      );
      final editedOriginal =
          composerKey.currentState!.pendingAttachmentsForTesting.single;
      expect(editedOriginal.storagePath, startsWith('temp_edited/'));

      final addedOriginal = await addImage(tester, 'new-image');
      await tester.runAsync(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(1, editedBytes),
      );
      final editedAdded = composerKey.currentState!.pendingAttachmentsForTesting
          .singleWhere((attachment) => attachment.id == addedOriginal.id);
      expect(editedAdded.storagePath, startsWith('temp_edited/'));

      Future<void> remove(String id) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey('pending_att_$id')),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pump();
      }

      await remove(source.id);
      await remove(addedOriginal.id);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });

      expect(
        await AttachmentStorage.readFile(source.storagePath),
        sourceBytes,
        reason: 'the original message must keep its source file',
      );
      expect(
        await AttachmentStorage.readFile(editedOriginal.storagePath),
        isNull,
        reason: 'a removed original edit replacement must not be orphaned',
      );
      expect(
        await AttachmentStorage.readFile(editedAdded.storagePath),
        isNull,
        reason: 'a removed new edit replacement must not be orphaned',
      );
    },
  );

  testWidgets(
    'disposing while save is pending cleans up the unreferenced saved edit',
    (tester) async {
      await mountComposer(tester);
      await addImage(tester, 'edited');
      final saveStarted = Completer<void>();
      final finishSave = Completer<void>();
      String? savedPath;
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      AttachmentStorage.saveEditedFileOverrideForTesting =
          (fileName, bytes) async {
        savedPath = await AttachmentStorage.saveFile(fileName, bytes);
        if (!saveStarted.isCompleted) saveStarted.complete();
        await finishSave.future;
        return 'temp_edited/${savedPath!.split('/').last}';
      };

      final edit = composerKey.currentState!
          .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
      await tester.runAsync(() => saveStarted.future);
      await tester.pumpWidget(const SizedBox.shrink());
      finishSave.complete();
      await tester.runAsync(() => edit);

      final files = await Directory('${root.path}/attachments').list().toList();
      expect(
        files,
        hasLength(1),
        reason: 'only the original attachment should remain',
      );
    },
  );
}
