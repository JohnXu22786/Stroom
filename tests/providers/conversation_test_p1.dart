Warning: truncated output (original token count: 3984)
Total output lines: 409

part of 'conversation_test.dart';

void conversationGroup1() {
  // ===================================================================
  // 1. Conversation model - draftText serialization
  // ===================================================================
  group('Conversation model - draftText serialization', () {
    test('draftText is preserved in toMap/fromMap round-trip', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'This is a draft message that was not sent yet',
      );
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(
          restored.draftText, 'This is a draft message that was not sent yet');
    });

    test('draftText survives toMap/fromMap round-trip with empty draft', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, '');
    });

    test('missing draftText in map defaults to empty string', () {
      final map = <String, dynamic>{
        'id': 'test',
        'title': 'Test',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
        'messages': [],
        'isPinned': false,
        'sortOrder': 0,
      };
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, '');
    });

    test('draftText with special characters survives round-trip', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Hello\nWorld\tTest 你好 🎉 \$100',
      );
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, 'Hello\nWorld\tTest 你好 🎉 \$100');
    });
  });

  // ===================================================================
  // 2. ConversationsNotifier - saveDraft
  // ===================================================================
  group('ConversationsNotifier - saveDraft', () {
    test('saveDraft stores draft for the correct conversation', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('conv-1', 'Hello, this is a draft');

      expect(notifier.state[0].draftText, 'Hello, this is a draft');
      expect(notifier.state[1].draftText, '');
    });

    test('different conversations have independent drafts', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('conv-1', 'Draft for conversation 1');
      notifier.saveDraft('conv-2', 'Draft for conversation 2');

      expect(notifier.state[0].draftText, 'Draft for conversation 1');
      expect(notifier.state[1].draftText, 'Draft for conversation 2');
    });

    test('saveDraft with empty string clears the draft', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Old draft content',
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('test', '');

      expect(notifier.state[0].draftText, '');
    });

    test('saveDraft on non-existent conversation does not crash', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Should not throw
      notifier.saveDraft('non-existent', 'Some draft');

      // Existing conversation should be unaffected
      expect(notifier.state[0].draftText, '');
    });

    test('updating draft multiple times keeps only the latest value', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('test', 'First version');
      notifier.saveDraft('test', 'Second version');
      notifier.saveDraft('test', 'Third version');

      expect(notifier.state[0].draftText, 'Third version');
    });

    test('sending a message (via updateMessages) does NOT clear draftText',
        () async {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Unsent draft',
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.updateMessages('test', [
        ChatMessage(id: 'm1', role: 'user', content: 'Sent message'),
      ]);

      // Draft text should be preserved when sending a message via updateMessages
      // (the composer will clear it separately via saveDraft)
      expect(notifier.state[0].draftText, 'Unsent draft');
    });
  });

  // ===================================================================
  // 3. ConversationsNotifier - createConversation prepends
  // ===================================================================
  group('ConversationsNotifier - createConversation prepends', () {
    testWidgets('new conversation is prepended at index 0', (tester) async {
      final container = _createContainer(initialState: []);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();
      expect(notifier.state.length, 1);
      final firstId = notifier.state[0].id;

      notifier.createConversation();
      expect(notifier.state.length, 2);

      // CLIENT REQUIREMENT: New conversations should…984 tokens truncated…'
              '未添加的工具保持关闭，不能退回自动启用全部');
      expect(conv.lastUsedModelName, isNull);
    });

    testWidgets(
        'topic under assistant with UNCONFIGURED tool defaults keeps the '
        'legacy auto-enable-all contract', (tester) async {
      final assistant = Assistant(
        name: '助手',
        prompt: '你好',
        // 未配置 defaultToolNames（null）：从未打开默认设置 tab 的助手
      );
      final container = _containerWithAssistants([assistant]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation(assistantId: assistant.id);

      final conv = notifier.state.single;
      expect(conv.hasExplicitEnabledMcpTools, isFalse,
          reason: '从未配置默认工具的助手，其新话题保持原有"自动启用全部工具"行为');
      expect(conv.enabledMcpToolNames, isEmpty);
    });

    testWidgets(
        'topic created without assistant keeps the auto-enable-all contract',
        (tester) async {
      final assistant = Assistant(
        name: '助手',
        prompt: '你好',
        defaultToolNames: {'web_search'},
      );
      final container = _containerWithAssistants([assistant]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();

      final conv = notifier.state.single;
      expect(conv.assistantId, isNull);
      expect(conv.hasExplicitEnabledMcpTools, isFalse,
          reason: '无助手上下文的对话保持原行为：未设置显式偏好，由聊天页自动启用全部工具');
      expect(conv.lastUsedModelName, isNull);
    });
    testWidgets(
        'defaults round-trip through serialization (empty set survives)',
        (tester) async {
      final assistant = Assistant(
        name: '助手',
        prompt: '你好',
        defaultModelName: 'claude-3.5 | Anthropic',
        defaultToolNames: {},
      );
      final container = _containerWithAssistants([assistant]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation(assistantId: assistant.id);
      final conv = notifier.state.single;
      final restored = Conversation.fromMap(conv.toMap());

      expect(restored.hasExplicitEnabledMcpTools, isTrue);
      expect(restored.enabledMcpToolNames, isEmpty);
      expect(restored.lastUsedModelName, 'claude-3.5 | Anthropic');
    });

    testWidgets(
        'configured-empty defaults survive a restart and keep tools OFF in '
        'new topics', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // 模拟首次配置：助手带显式空工具默认（配置过但全关）
      final notifierA = AssistantsNotifier();
      notifierA.state = [
        Assistant(name: '助手', prompt: '你好', defaultToolNames: {}),
      ];

      // 模拟重启：序列化 → 反序列化（跨层验证 null 与空集合的区分存活）
      final reloaded = AssistantsNotifier()..loadFromJson(notifierA.toJson());
      final assistant = reloaded.state.single;
      expect(assistant.defaultToolNames, isNotNull,
          reason: '"配置过但全关"不能因序列化丢失而退回"从未配置"');
      expect(assistant.defaultToolNames, isEmpty);

      // 重启后新建话题：工具必须保持全关（显式偏好）
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final n = ConversationsNotifier(ref);
            n.state = [];
            return n;
          }),
          assistantProvider.overrideWith((ref) {
            final n = AssistantsNotifier();
            n.state = [...reloaded.state];
            return n;
          }),
        ],
      );
      container
          .read(conversationsProvider.notifier)
          .createConversation(assistantId: assistant.id);
      final conv = container.read(conversationsProvider).single;
      expect(conv.hasExplicitEnabledMcpTools, isTrue);
      expect(conv.enabledMcpToolNames, isEmpty);
    });
  });

  // ===================================================================
  // 4. ConversationsNotifier - selectConversation does not update updatedAt
  // ===================================================================
  group('ConversationsNotifier - selectConversation does not update updatedAt',
      () {
    testWidgets('calling selectConversation keeps updatedAt unchanged',
        (tester) async {
      final conv = Conversation(
        id: 'test-conv',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        messages: [],
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      final originalUpdatedAt = notifier.state[0].updatedAt;

      notifier.selectConversation('test-conv');
      // CLIENT REQUIREMENT: selecting a conversation should NOT change its time
      expect(notifier.state[0].updatedAt, originalUpdatedAt);
    });

    test('selecting a conversation does not mark its error reply as read', () {
      final previousReply = ChatMessage(
        id: 'previous-reply',
        role: 'assistant',
        content: 'Earlier successful reply',
      );
      final errorReply = ChatMessage(
        id: 'error-reply',
        role: 'assistant',
        content: 'Request failed',
        isError: true,
      );
      final conv = Conversation(
        id: 'error-conv',
        title: 'Failed conversation',
        messages: [previousReply, errorReply],
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.selectConversation('error-conv');

      expect(notifier.state.single.lastReadMessageId, isNull);
      expect(notifier.state.single.messages.last.isError, isTrue);
    });
  });
}
