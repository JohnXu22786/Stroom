part of 'conversation_test.dart';

class _RejectRawConversationDataStore extends InMemorySharedPreferencesStore {
  _RejectRawConversationDataStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.conversations' && value is String) {
      final records = jsonDecode(value) as List;
      final hasRawData = records.whereType<Map>().any((record) {
        final messages = record['messages'];
        return messages is List &&
            messages.whereType<Map>().any(
                  (message) =>
                      message['rawRequest'] != null ||
                      message['rawResponse'] != null,
                );
      });
      if (hasRawData) return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _RejectConversationWritesStore extends InMemorySharedPreferencesStore {
  _RejectConversationWritesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.conversations') return Future<bool>.value(false);
    return super.setValue(valueType, key, value);
  }
}

void conversationGroup6() {
  group('Conversation TODO persistence', () {
    test('updates only the selected conversation and persists its items',
        () async {
      final first = Conversation(id: 'first', title: 'First');
      final second = Conversation(id: 'second', title: 'Second');
      final container = _createContainer(initialState: [first, second]);
      addTearDown(container.dispose);

      await container.read(conversationsProvider.notifier).updateTodoItems(
        'first',
        const [TodoItem(content: 'Review notes', position: 0)],
      );

      final state = container.read(conversationsProvider);
      expect(state.first.todoItems.single.content, 'Review notes');
      expect(state.last.todoItems, isEmpty);
      expect(Conversation.fromMap(state.first.toMap()).todoItems.single.content,
          'Review notes');
    });

    test('raw-data fallback save keeps conversation todos', () async {
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = _RejectRawConversationDataStore();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;

      final id = notifier.createConversation();
      await notifier.updateTodoItems(
        id,
        const [TodoItem(content: 'Persist this list', position: 0)],
      );
      await notifier.updateMessages(id, [
        ChatMessage(
          id: 'assistant-with-raw-data',
          role: 'assistant',
          content: 'Saved',
          rawRequest: const {'request': 'captured'},
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final saved = (jsonDecode(prefs.getString('conversations')!) as List)
          .single as Map<String, dynamic>;
      final restored = Conversation.fromMap(saved);
      expect(restored.messages.single.rawRequest, isNull);
      expect(restored.todoItems.single.content, 'Persist this list');
    });

    test('reports failed todo persistence to the tool handler', () async {
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance =
          _RejectConversationWritesStore();
      addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.ready;
      final id = notifier.createConversation();
      final result = await TodoToolService.handleConversationTodo(
        {
          'todos': [
            {'content': 'This write must fail'}
          ],
        },
        currentTodos: const [],
        saveTodos: (todos) => notifier.updateTodoItems(id, todos),
      );

      expect(result, contains('could not be saved'));
    });
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
