// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

Future<T> _runInTestZone<T>(Future<T> Function() callback) => callback();

void main() {
  late Directory root;
  late PathProviderPlatform previousPathProvider;
  final storageFiles = <String, List<int>>{};
  var nextStorageFileId = 0;

  Future<String> saveEditedFileInMemory(
      String fileName, Uint8List bytes) async {
    final path = 'temp_edited/test_${nextStorageFileId++}_$fileName';
    storageFiles[path] = bytes;
    return path;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousPathProvider = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('composer_edit_race');
    PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
    await Directory('${root.path}/tmp').create(recursive: true);
    await Directory('${root.path}/attachments').create(recursive: true);
    AttachmentStorage.resetOverridesForTesting();
    storageFiles.clear();
    nextStorageFileId = 0;
    AttachmentStorage.saveFileOverrideForTesting = (fileName, bytes) async {
      final path = 'attachments/test_${nextStorageFileId++}_$fileName';
      storageFiles[path] = bytes;
      return path;
    };
    AttachmentStorage.saveEditedFileOverrideForTesting = saveEditedFileInMemory;
    AttachmentStorage.readFileOverrideForTesting = (path) async {
      final bytes = storageFiles[path];
      return bytes == null ? null : Uint8List.fromList(bytes);
    };
    AttachmentStorage.deleteFileOverrideForTesting = (path) async {
      storageFiles.remove(path);
      return true;
    };
  });

  tearDown(() async {
    AttachmentStorage.resetOverridesForTesting();
    PathProviderPlatform.instance = previousPathProvider;
    await root.delete(recursive: true);
  });

  late GlobalKey<ChatComposerWidgetState> composerKey;
  List<Attachment>? sent;

  Future<void> pumpComposer(
    WidgetTester tester, {
    Attachment? editingAttachment,
    String conversationId = 'race-test',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(
            (ref) => ConversationsNotifier(ref),
          ),
          activeConversationIdProvider.overrideWith((ref) => conversationId),
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
              conversationId: conversationId,
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

  Future<void> mountComposer(
    WidgetTester tester, {
    Attachment? editingAttachment,
    String conversationId = 'race-test',
  }) async {
    composerKey = GlobalKey<ChatComposerWidgetState>();
    sent = null;
    await pumpComposer(
      tester,
      editingAttachment: editingAttachment,
      conversationId: conversationId,
    );
  }

  Future<Attachment> addImage(WidgetTester tester, String id) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    await _runInTestZone(
      () => composerKey.currentState!.addPendingAttachmentForTesting(
        '$id.png',
        bytes,
      ),
    );
    await tester.pump();
    return composerKey.currentState!.pendingAttachmentsForTesting.singleWhere(
      (attachment) => attachment.fileName == '$id.png',
    );
  }

  Future<void> removeFile(String storagePath) async {
    storageFiles.remove(storagePath);
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

      late Future<void> edit;
      await _runInTestZone(() async {
        edit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await cleanupStarted.future;
      });
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('pending_att_${editedOriginal.id}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      finishCleanup.complete();
      await _runInTestZone(() => edit);

      expect(
        storageFiles.keys,
        hasLength(1),
        reason: 'removal must clean up the saved edit file',
      );
      expect(
        storageFiles.keys.single,
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

      late Future<void> edit;
      await _runInTestZone(() async {
        edit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await cleanupStarted.future;
      });
      composerKey.currentState!.reorderPendingAttachmentsForTesting(0, 1);
      await tester.pump();
      finishCleanup.complete();
      await _runInTestZone(() => edit);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent?.map((att) => att.id).toList(), [
        otherOriginal.id,
        editedOriginal.id,
      ]);
      final edited = sent!.last;
      expect(edited.storagePath, startsWith('temp_edited/'));
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(edited.storagePath),
        ),
        editedBytes,
      );
    },
  );

  testWidgets(
    'overlapping edits keep only the replacement that commits last',
    (tester) async {
      await mountComposer(tester);
      await addImage(tester, 'edited');
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      final savedPaths = List<String?>.filled(2, null);
      final releaseSave = List.generate(2, (_) => Completer<void>());
      final bothSaved = Completer<void>();
      var saveCount = 0;
      AttachmentStorage.saveEditedFileOverrideForTesting =
          (fileName, bytes) async {
        final index = saveCount++;
        savedPaths[index] = await saveEditedFileInMemory(fileName, bytes);
        if (savedPaths.every((path) => path != null) &&
            !bothSaved.isCompleted) {
          bothSaved.complete();
        }
        await releaseSave[index].future;
        return savedPaths[index]!;
      };

      late Future<void> firstEdit;
      late Future<void> secondEdit;
      await _runInTestZone(() async {
        firstEdit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        secondEdit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await bothSaved.future;
      });

      releaseSave[1].complete();
      await _runInTestZone(() => secondEdit);
      releaseSave[0].complete();
      await _runInTestZone(() => firstEdit);

      final pending =
          composerKey.currentState!.pendingAttachmentsForTesting.single;
      expect(pending.storagePath, savedPaths[1]);
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(savedPaths[0]!),
        ),
        isNull,
        reason: 'a superseded overlapping edit must clean up its saved file',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(savedPaths[1]!),
        ),
        editedBytes,
      );
    },
  );

  testWidgets(
    'a newer overlapping edit wins when the older save finishes first',
    (tester) async {
      await mountComposer(tester);
      final original = await addImage(tester, 'edited');
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      final savedPaths = List<String?>.filled(2, null);
      final releaseSave = List.generate(2, (_) => Completer<void>());
      final bothSaved = Completer<void>();
      var saveCount = 0;
      AttachmentStorage.saveEditedFileOverrideForTesting =
          (fileName, bytes) async {
        final index = saveCount++;
        savedPaths[index] = await saveEditedFileInMemory(fileName, bytes);
        if (savedPaths.every((path) => path != null) &&
            !bothSaved.isCompleted) {
          bothSaved.complete();
        }
        await releaseSave[index].future;
        return savedPaths[index]!;
      };

      late Future<void> olderEdit;
      late Future<void> newerEdit;
      await _runInTestZone(() async {
        olderEdit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        newerEdit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await bothSaved.future;
      });

      releaseSave[0].complete();
      await _runInTestZone(() => olderEdit);
      expect(
        composerKey
            .currentState!.pendingAttachmentsForTesting.single.storagePath,
        original.storagePath,
        reason:
            'an older request must not publish while a newer save is pending',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(savedPaths[0]!),
        ),
        isNull,
        reason: 'the superseded older save must be deleted',
      );

      releaseSave[1].complete();
      await _runInTestZone(() => newerEdit);
      expect(
        composerKey
            .currentState!.pendingAttachmentsForTesting.single.storagePath,
        savedPaths[1],
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(savedPaths[1]!),
        ),
        editedBytes,
      );
    },
  );

  testWidgets(
    'removing edited replacements deletes them and preserves original source',
    (tester) async {
      final sourceBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      final sourcePath = await _runInTestZone(
        () => AttachmentStorage.saveFile('source.png', sourceBytes),
      );
      final source = Attachment(
        id: 'source-image',
        fileName: 'source.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'source-hash',
        storagePath: sourcePath,
        fileSize: sourceBytes.length,
        base64Data: base64Encode(sourceBytes),
      );
      await mountComposer(tester, editingAttachment: source);
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );

      await _runInTestZone(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes),
      );
      final editedOriginal =
          composerKey.currentState!.pendingAttachmentsForTesting.single;
      expect(editedOriginal.storagePath, startsWith('temp_edited/'));

      await _runInTestZone(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes),
      );
      final latestEditedOriginal =
          composerKey.currentState!.pendingAttachmentsForTesting.single;
      expect(
          latestEditedOriginal.storagePath, isNot(editedOriginal.storagePath));
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(editedOriginal.storagePath),
        ),
        isNull,
        reason: 'a superseded edit replacement must be deleted',
      );

      final addedOriginal = await addImage(tester, 'new-image');
      await _runInTestZone(() async {
        await composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(1, editedBytes);
      });
      final editedAdded = composerKey.currentState!.pendingAttachmentsForTesting
          .singleWhere((attachment) => attachment.id == addedOriginal.id);
      expect(editedAdded.storagePath, startsWith('temp_edited/'));
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(addedOriginal.storagePath),
        ),
        isNull,
        reason: 'editing a new attachment must delete its replaced file',
      );

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
      await tester.pump(const Duration(milliseconds: 30));

      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(source.storagePath),
        ),
        sourceBytes,
        reason: 'the original message must keep its source file',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(editedOriginal.storagePath),
        ),
        isNull,
        reason: 'a removed original edit replacement must not be orphaned',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(latestEditedOriginal.storagePath),
        ),
        isNull,
        reason:
            'the current original edit replacement must be deleted on removal',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(editedAdded.storagePath),
        ),
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
        savedPath = await saveEditedFileInMemory(fileName, bytes);
        if (!saveStarted.isCompleted) saveStarted.complete();
        await finishSave.future;
        return savedPath!;
      };

      late Future<void> edit;
      await _runInTestZone(() async {
        edit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await saveStarted.future;
      });
      await tester.pumpWidget(const SizedBox.shrink());
      finishSave.complete();
      await _runInTestZone(() => edit);

      expect(
        storageFiles.keys,
        hasLength(1),
        reason: 'only the original attachment should remain',
      );
    },
  );

  testWidgets(
    'canceling an edit after switching conversations cleans its original cache',
    (tester) async {
      final deletedCacheConversations = <String?>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedCacheConversations.add(conversationId);
        return true;
      };

      await mountComposer(tester, conversationId: 'original-conversation');
      final original = await addImage(tester, 'source');
      await pumpComposer(
        tester,
        editingAttachment: original,
        conversationId: 'original-conversation',
      );

      final editedBytes = Uint8List.fromList([
        ...base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
        0,
      ]);
      await _runInTestZone(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes),
      );
      await tester.pump();
      final newlyAdded = await addImage(tester, 'newly-added');

      await pumpComposer(
        tester,
        editingAttachment: original,
        conversationId: 'new-conversation',
      );
      await pumpComposer(tester, conversationId: 'new-conversation');

      expect(deletedCacheConversations, isNotEmpty);
      expect(
        deletedCacheConversations,
        everyElement('original-conversation'),
        reason:
            'cancel cleanup must not delete a cache for the new conversation',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(newlyAdded.storagePath),
        ),
        isNull,
        reason: 'canceling edit must delete newly added attachment files',
      );
    },
  );

  testWidgets(
    'removing a new attachment in edit mode deletes its stored file',
    (tester) async {
      await mountComposer(tester);
      final original = await addImage(tester, 'original');
      await pumpComposer(tester, editingAttachment: original);
      final newlyAdded = await addImage(tester, 'newly-added');

      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('pending_att_${newlyAdded.id}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(newlyAdded.storagePath),
        ),
        isNull,
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(original.storagePath),
        ),
        isNotNull,
        reason: 'removing a new edit attachment must preserve the source file',
      );
    },
  );

  testWidgets(
    'submitting an edit after switching conversations cleans its original cache',
    (tester) async {
      final deletedCacheConversations = <String?>[];
      AttachmentStorage.deleteCompressedImageOverrideForTesting =
          ({required conversationId, required hash}) async {
        deletedCacheConversations.add(conversationId);
        return true;
      };

      await mountComposer(tester, conversationId: 'original-conversation');
      final original = await addImage(tester, 'original');
      await pumpComposer(
        tester,
        editingAttachment: original,
        conversationId: 'original-conversation',
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('pending_att_${original.id}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await pumpComposer(
        tester,
        editingAttachment: original,
        conversationId: 'new-conversation',
      );

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(deletedCacheConversations, isNotEmpty);
      expect(
        deletedCacheConversations,
        everyElement('original-conversation'),
        reason:
            'submitting the old edit must not delete a new conversation cache',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(original.storagePath),
        ),
        isNotNull,
        reason:
            'submitting the edit must preserve its original attachment file',
      );
    },
  );

  testWidgets(
    'canceling edit during old replacement cleanup deletes the latest edit',
    (tester) async {
      await mountComposer(tester);
      final source = await addImage(tester, 'source');
      await pumpComposer(tester, editingAttachment: source);
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );

      await _runInTestZone(
        () => composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes),
      );
      final firstReplacement =
          composerKey.currentState!.pendingAttachmentsForTesting.single;
      final oldCleanupStarted = Completer<void>();
      final finishOldCleanup = Completer<void>();
      final latestReplacementDeleted = Completer<void>();
      String? latestReplacementPath;
      AttachmentStorage.deleteFileOverrideForTesting = (path) async {
        if (path == firstReplacement.storagePath) {
          if (!oldCleanupStarted.isCompleted) oldCleanupStarted.complete();
          await finishOldCleanup.future;
        }
        await removeFile(path);
        if (path == latestReplacementPath &&
            !latestReplacementDeleted.isCompleted) {
          latestReplacementDeleted.complete();
        }
        return true;
      };

      late Future<void> secondEdit;
      await _runInTestZone(() async {
        secondEdit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await oldCleanupStarted.future;
      });
      latestReplacementPath = composerKey
          .currentState!.pendingAttachmentsForTesting.single.storagePath;

      await pumpComposer(tester);
      await tester.pump();
      await _runInTestZone(() => latestReplacementDeleted.future);
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(latestReplacementPath!),
        ),
        isNull,
      );

      finishOldCleanup.complete();
      await _runInTestZone(() => secondEdit);
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(source.storagePath),
        ),
        isNotNull,
        reason: 'canceling edit must preserve the source message attachment',
      );
    },
  );

  testWidgets(
    'a canceled edit cannot commit into a reopened session for the same message',
    (tester) async {
      final sourceBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );
      final sourcePath = await _runInTestZone(
        () => AttachmentStorage.saveFile('source.png', sourceBytes),
      );
      final source = Attachment(
        id: 'source-image',
        fileName: 'source.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'source-hash',
        storagePath: sourcePath,
        fileSize: sourceBytes.length,
        base64Data: base64Encode(sourceBytes),
      );
      await mountComposer(tester, editingAttachment: source);

      final saveStarted = Completer<void>();
      final finishSave = Completer<void>();
      String? savedEditedPath;
      AttachmentStorage.saveEditedFileOverrideForTesting =
          (fileName, bytes) async {
        savedEditedPath = await saveEditedFileInMemory(fileName, bytes);
        if (!saveStarted.isCompleted) saveStarted.complete();
        await finishSave.future;
        return savedEditedPath!;
      };
      final editedBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      );

      late Future<void> edit;
      await _runInTestZone(() async {
        edit = composerKey.currentState!
            .updatePendingAttachmentAfterEditForTesting(0, editedBytes);
        await tester.pump();
        await saveStarted.future;
      });

      await pumpComposer(tester);
      await pumpComposer(tester, editingAttachment: source);
      finishSave.complete();
      await _runInTestZone(() => edit);

      expect(
        composerKey
            .currentState!.pendingAttachmentsForTesting.single.storagePath,
        source.storagePath,
        reason:
            'the canceled save must not replace an attachment in a new edit session',
      );
      expect(
        await _runInTestZone(
          () => AttachmentStorage.readFile(savedEditedPath!),
        ),
        isNull,
        reason: 'the stale save file must be removed',
      );
    },
  );
}
