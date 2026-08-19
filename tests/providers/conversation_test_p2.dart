part of 'conversation_test.dart';

void conversationGroup2() {
  // ===================================================================
  // 5. ConversationsNotifier - updateMessages preserves list position
  // ===================================================================
  group('ConversationsNotifier - updateMessages preserves list position', () {
    testWidgets('updateMessages does not reorder conversations',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: 'First',
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
        messages: [],
      );
      final conv2 = Conversation(
        id: 'conv-2',
        title: 'Second',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        messages: [],
      );
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      // Update messages in conv1
      await notifier.updateMessages('conv-1', [
        ChatMessage(id: 'msg-1', role: 'user', content: 'Hello'),
        ChatMessage(id: 'msg-2', role: 'assistant', content: 'Hi there'),
      ]);
      // Let the persist timer complete
      await tester.pump(const Duration(milliseconds: 600));

      // CLIENT REQUIREMENT: updating messages should NOT move conversation to top
      expect(notifier.state[0].id, 'conv-1');
      expect(notifier.state[1].id, 'conv-2');
    });

    testWidgets('updateMessages does update updatedAt timestamp',
        (tester) async {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      final before = notifier.state[0].updatedAt;

      // selectConversation should NOT change updatedAt
      notifier.selectConversation('test');
      expect(notifier.state[0].updatedAt, before);

      // updateMessages SHOULD change updatedAt (for metadata/timestamp purposes)
      // but should NOT change list position
      await notifier.updateMessages('test', [
        ChatMessage(id: 'm1', role: 'user', content: 'Hi'),
      ]);
      // Let the persist timer complete
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.state[0].updatedAt.isAfter(before), isTrue);
      // Position should remain unchanged
      expect(notifier.state[0].id, 'test');
    });
  });

  // ===================================================================
  // 6. ConversationsNotifier - reorderConversation
  // ===================================================================
  group('ConversationsNotifier - reorderConversation', () {
    testWidgets('reorderConversation preserves manually set order',
        (tester) async {
      final container = _createContainer(initialState: []);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();
      notifier.createConversation();
      notifier.createConversation();

      final ids = notifier.state.map((c) => c.id).toList();

      // Move the last item to index 0 (top)
      notifier.reorderConversation(2, 0);
      await tester.pump(const Duration(milliseconds: 600));

      // CLIENT REQUIREMENT: manual reordering should be preserved
      expect(notifier.state[0].id, ids[2]);
      expect(notifier.state[1].id, ids[0]);
      expect(notifier.state[2].id, ids[1]);
    });

    testWidgets(
        'reorderConversation keeps state pinned-first: dragging a pinned '
        'conversation below unpinned ones snaps back to the pinned block',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-pin',
        title: 'Pinned',
        isPinned: true,
      );
      final conv2 = Conversation(
        id: 'conv-normal',
        title: 'Normal',
      );
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      // 把置顶对话拖到非置顶区：显示层永远是"置顶在前"，拖拽结果
      // 吸附回置顶块（存储顺序与显示顺序一致，不产生隐藏交错）。
      notifier.reorderConversation(0, 1);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifier.state[0].id, 'conv-pin');
      expect(notifier.state[1].id, 'conv-normal');
    });

    testWidgets(
        'reorderConversation moves a pinned conversation within the pinned '
        'block exactly as dragged', (tester) async {
      final conv1 = Conversation(
        id: 'conv-pin-1',
        title: 'Pinned 1',
        isPinned: true,
      );
      final conv2 = Conversation(
        id: 'conv-pin-2',
        title: 'Pinned 2',
        isPinned: true,
      );
      final conv3 = Conversation(
        id: 'conv-normal',
        title: 'Normal',
      );
      final container = _createContainer(initialState: [conv1, conv2, conv3]);
      final notifier = container.read(conversationsProvider.notifier);

      // onReorderItem 语义（移除后索引）：把 conv-pin-1 移到置顶块末尾。
      notifier.reorderConversation(0, 1);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifier.state.map((c) => c.id).toList(),
          ['conv-pin-2', 'conv-pin-1', 'conv-normal']);
    });
  });

  // ===================================================================
  // 7. ConversationsNotifier - togglePin preserves updatedAt
  // ===================================================================
  group('ConversationsNotifier - togglePin preserves updatedAt', () {
    testWidgets('togglePin does NOT change updatedAt', (tester) async {
      final originalTime = DateTime(2026, 5, 15, 10, 30, 0);
      final conv = Conversation(
        id: 'test-conv',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: originalTime,
        isPinned: false,
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Pin the conversation
      notifier.togglePin('test-conv');
      expect(notifier.state[0].isPinned, isTrue);
      // CLIENT REQUIREMENT: pinning should NOT change updatedAt
      expect(notifier.state[0].updatedAt, originalTime);

      // Unpin the conversation
      notifier.togglePin('test-conv');
      expect(notifier.state[0].isPinned, isFalse);
      // CLIENT REQUIREMENT: unpinning should NOT change updatedAt
      expect(notifier.state[0].updatedAt, originalTime);

      // Flush the persist timer to avoid "pending timer" error
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('togglePin correctly toggles isPinned state', (tester) async {
      final conv = Conversation(
        id: 'test-conv-2',
        title: 'Test 2',
        updatedAt: DateTime(2026, 6, 1),
        isPinned: false,
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Initially not pinned
      expect(notifier.state[0].isPinned, isFalse);

      // Toggle to pinned
      notifier.togglePin('test-conv-2');
      expect(notifier.state[0].isPinned, isTrue);

      // Toggle back to not pinned
      notifier.togglePin('test-conv-2');
      expect(notifier.state[0].isPinned, isFalse);

      // Flush the persist timer to avoid "pending timer" error
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
