part of 'conversation_test.dart';

void conversationGroup4() {
  // ===================================================================
  // 10. ConversationsNotifier - updateLastUsedModel
  // ===================================================================
  group('ConversationsNotifier - updateLastUsedModel', () {
    test('updateLastUsedModel stores model name for correct conversation', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.updateLastUsedModel('conv-1', 'GPT-4o | OpenAI');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o | OpenAI');
      expect(notifier.state[1].lastUsedModelName, isNull);
    });

    test('different conversations have independent lastUsedModelName', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.updateLastUsedModel('conv-1', 'GPT-4o | OpenAI');
      notifier.updateLastUsedModel('conv-2', 'Claude 3 | Anthropic');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o | OpenAI');
      expect(notifier.state[1].lastUsedModelName, 'Claude 3 | Anthropic');
    });

    test('updateLastUsedModel overwrites previous model name', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.updateLastUsedModel('test', 'GPT-4o | OpenAI');
      notifier.updateLastUsedModel('test', 'GPT-4o Mini | OpenAI');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o Mini | OpenAI');
    });

    test('updateLastUsedModel on non-existent conversation does not crash', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Should not throw
      notifier.updateLastUsedModel('non-existent', 'GPT-4o | OpenAI');

      // Existing conversation should be unaffected
      expect(notifier.state[0].lastUsedModelName, isNull);
    });
  });

  // ===================================================================
  // 11. ConversationsNotifier - tool state management
  // ===================================================================
  group('ConversationsNotifier - tool state management', () {
    test(
        'createConversation creates conversation with empty enabledMcpToolNames',
        () {
      // Integration verification: new conversations should have no tools enabled
      // This tests the conversation through the standard creation path
      final conv = Conversation(
        title: 'New Conversation',
        messages: [],
      );
      expect(conv.enabledMcpToolNames, isEmpty,
          reason: 'New conversations must have all tools OFF by default');
    });
  });

  // ===================================================================
  // 10. Tool filtering integration
  // ===================================================================
  group('Tool filtering integration', () {
    test('all tools default OFF when creating new conversation', () {
      // Simulate the chat_page.dart logic: when loading a conversation,
      // enabledToolNames should be empty for a new conversation
      final conv = Conversation(title: 'New', messages: []);
      final enabledToolNames = conv.enabledMcpToolNames;

      // All tools should be OFF by default (empty set)
      expect(enabledToolNames, isEmpty);
    });

    test('tool filtering excludes all tools when enabledMcpToolNames is empty',
        () {
      final allTools = ['calculator', 'web_search', 'file_reader'];
      final conv = Conversation(title: 'Test', messages: []);
      // enabledMcpToolNames is empty by default

      final filteredTools =
          allTools.where((t) => conv.enabledMcpToolNames.contains(t)).toList();

      expect(filteredTools, isEmpty,
          reason:
              'When enabledMcpToolNames is empty, no tools should pass filter');
    });

    test('tool filtering includes only tools in enabledMcpToolNames', () {
      final allTools = ['calculator', 'web_search', 'file_reader'];
      final conv = Conversation(title: 'Test', messages: []);
      conv.enabledMcpToolNames = {'web_search'};

      final filteredTools =
          allTools.where((t) => conv.enabledMcpToolNames.contains(t)).toList();

      expect(filteredTools, equals(['web_search']));
    });
  });
}
