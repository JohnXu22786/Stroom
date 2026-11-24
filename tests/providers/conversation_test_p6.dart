part of 'conversation_test.dart';

void conversationGroup6() {
  group('ConversationsNotifier corrupt payload recovery', () {
    test('backs up valid JSON with a non-list shape', () async {
      const corruptJson = '{"unexpected":"payload"}';
      SharedPreferences.setMockInitialValues({'conversations': corruptJson});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('conversations.corrupt.'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), corruptJson);
      expect(prefs.getString('conversations'), isNull);
    });

    test('backs up an empty stored conversations payload', () async {
      SharedPreferences.setMockInitialValues({'conversations': ''});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('conversations.corrupt.'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), '');
      expect(prefs.getString('conversations'), isNull);
    });

    test(
      'keeps source payload and blocks saves when backup writes fail',
      () async {
        const corruptJson = '{"unexpected":"payload"}';
        SharedPreferences.setMockInitialValues({'conversations': corruptJson});
        var backupAttempts = 0;
        final container = ProviderContainer(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(
                ref,
                corruptConversationBackupWriter: (_, __, ___) async {
                  backupAttempts++;
                  return false;
                },
              );
              notifier.loadForTesting();
              return notifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(conversationsProvider.notifier);
        await notifier.ready;
        final saved = await notifier.persistNowForTesting();

        final prefs = await SharedPreferences.getInstance();
        expect(saved, isFalse);
        expect(backupAttempts, 2);
        expect(prefs.getString('conversations'), corruptJson);
        expect(
          prefs.getKeys().where(
            (key) => key.startsWith('conversations.corrupt.'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'serializes backup retries with concurrent conversation saves',
      () async {
        const corruptJson = '{"unexpected":"payload"}';
        SharedPreferences.setMockInitialValues({'conversations': corruptJson});
        var backupAttempts = 0;
        final firstBackupStarted = Completer<void>();
        final firstBackup = Completer<bool>();
        final secondBackup = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(
                ref,
                corruptConversationBackupWriter: (_, __, ___) {
                  backupAttempts++;
                  if (backupAttempts == 1) return Future<bool>.value(false);
                  if (backupAttempts == 2) {
                    firstBackupStarted.complete();
                    return firstBackup.future;
                  }
                  return secondBackup.future;
                },
              );
              notifier.loadForTesting();
              return notifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(conversationsProvider.notifier);
        await notifier.ready;
        final firstSave = notifier.persistNowForTesting();
        await firstBackupStarted.future;
        final secondSave = notifier.persistNowForTesting();
        await Future<void>.delayed(Duration.zero);

        final overlappingBackupStarted = backupAttempts == 3;
        firstBackup.complete(true);
        await firstSave;
        if (overlappingBackupStarted) secondBackup.complete(true);
        await secondSave;

        expect(overlappingBackupStarted, isFalse);
      },
    );
  });

  // ===================================================================
  // 6. Draft attachments (unsent attachment snapshots) persistence
  // ===================================================================
  group('Conversation draft attachments persistence', () {
    test('draftAttachments 携带图片压缩 base64 往返', () {
      final draftAtt = Attachment(
        id: 'draft-1',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileType: 'image',
        hash: 'draft-hash',
        storagePath: 'attachments/draft-hash_1.jpg',
        fileSize: 4096,
        conversationId: 'conv-9',
      )..base64Data = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYH';

      final conv = Conversation(
        id: 'conv-9',
        title: '草稿对话',
        messages: [],
        draftText: 'hello',
        draftAttachments: [draftAtt],
      );

      final restored = Conversation.fromMap(conv.toMap());

      expect(restored.draftText, 'hello');
      expect(restored.draftAttachments, hasLength(1));
      expect(restored.draftAttachments[0].id, 'draft-1');
      expect(restored.draftAttachments[0].hash, 'draft-hash');
      expect(restored.draftAttachments[0].conversationId, 'conv-9');
      expect(restored.draftAttachments[0].base64Data,
          '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAYEBQYFBAYGBQYH',
          reason: '草稿附件的压缩 base64 必须随对话持久化（重启后发送零等待）');
    });

    test('草稿附件缺省为空；旧数据无 draftAttachments 字段兼容', () {
      final conv = Conversation(
        id: 'conv-10',
        title: 't',
        messages: [],
      );
      expect(conv.draftAttachments, isEmpty);

      // 模拟功能上线前的旧数据（无 draftAttachments 键）
      final oldMap = conv.toMap()..remove('draftAttachments');
      final restored = Conversation.fromMap(oldMap);
      expect(restored.draftAttachments, isEmpty);
    });

    test('损坏的草稿附件条目被跳过，不拖垮整条对话', () {
      final map = Conversation(
        id: 'conv-11',
        title: 't',
        messages: [],
      ).toMap();
      map['draftAttachments'] = [
        {'fileName': 123, 'storagePath': 456, 'fileType': null}, // 损坏
        {
          'id': 'ok-1',
          'fileName': 'a.png',
          'mimeType': 'image/png',
          'fileType': 'image',
          'hash': 'h-ok',
          'storagePath': 'attachments/h-ok_1.png',
          'fileSize': 10,
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];

      final restored = Conversation.fromMap(map);

      expect(restored.draftAttachments, hasLength(1));
      expect(restored.draftAttachments[0].id, 'ok-1');
    });
  });
}
