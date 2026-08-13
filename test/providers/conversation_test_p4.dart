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

      notifier.updateLastUsedModel('conv-1', 'GPT-4o | OpenAI',
          modelId: 'gpt-4o', providerName: 'OpenAI');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o | OpenAI');
      expect(notifier.state[0].lastUsedModelId, 'gpt-4o');
      expect(notifier.state[0].lastUsedProviderName, 'OpenAI');
      expect(notifier.state[1].lastUsedModelName, isNull);
      expect(notifier.state[1].lastUsedModelId, isNull);
    });

    test('different conversations have independent lastUsedModelName', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.updateLastUsedModel('conv-1', 'GPT-4o | OpenAI',
          modelId: 'gpt-4o', providerName: 'OpenAI');
      notifier.updateLastUsedModel('conv-2', 'Claude 3 | Anthropic',
          modelId: 'claude-3', providerName: 'Anthropic');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o | OpenAI');
      expect(notifier.state[0].lastUsedModelId, 'gpt-4o');
      expect(notifier.state[1].lastUsedModelName, 'Claude 3 | Anthropic');
      expect(notifier.state[1].lastUsedModelId, 'claude-3');
    });

    test('updateLastUsedModel overwrites previous model name', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.updateLastUsedModel('test', 'GPT-4o | OpenAI',
          modelId: 'gpt-4o', providerName: 'OpenAI');
      notifier.updateLastUsedModel('test', 'GPT-4o Mini | OpenAI',
          modelId: 'gpt-4o-mini', providerName: 'OpenAI');

      expect(notifier.state[0].lastUsedModelName, 'GPT-4o Mini | OpenAI');
      expect(notifier.state[0].lastUsedModelId, 'gpt-4o-mini');
      expect(notifier.state[0].lastUsedProviderName, 'OpenAI');
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
}
