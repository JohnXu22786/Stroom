part of 'conversation_test.dart';

void conversationGroup6() {
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
