part of 'conversation_test.dart';

void conversationGroup5() {
  // ===================================================================
  // 5. Persistence round-trip with reasoning + tool calls
  // ===================================================================
  group('Conversation persistence - reasoning + tool calls', () {
    test('ChatMessage with reasoningSections survives toMap/fromMap', () {
      final msg = ChatMessage(
        id: 'msg-1',
        role: 'assistant',
        content: 'The answer is 42',
        reasoningSections: ['Step 1: think', 'Step 2: decide'],
        toolCalls: [
          ToolCallData(
            id: 'call-1',
            name: 'calculator',
            arguments: {'expr': '40+2'},
            status: ToolCallStatus.completed,
            result: '42',
          ),
        ],
      );

      final map = msg.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.id, 'msg-1');
      expect(restored.role, 'assistant');
      expect(restored.content, 'The answer is 42');
      expect(restored.reasoningSections, isNotNull);
      expect(restored.reasoningSections!.length, 2);
      expect(restored.reasoningSections![0], 'Step 1: think');
      expect(restored.reasoningSections![1], 'Step 2: decide');
      expect(restored.toolCalls, isNotNull);
      expect(restored.toolCalls!.length, 1);
      expect(restored.toolCalls![0].id, 'call-1');
      expect(restored.toolCalls![0].name, 'calculator');
      expect(restored.toolCalls![0].status, ToolCallStatus.completed);
    });

    test(
        'Conversation with 4 messages (2 user + 2 assistant with reasoning+toolCalls) survives full round-trip',
        () {
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'What is 2+2?',
        ),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'Let me check...',
          reasoningSections: ['thinking about math'],
          toolCalls: [
            ToolCallData(
              id: 'tc1',
              name: 'calc',
              arguments: {'expr': '2+2'},
              status: ToolCallStatus.completed,
              result: '4',
            ),
          ],
        ),
        ChatMessage(
          id: 'u2',
          role: 'user',
          content: 'What about 3+3?',
        ),
        ChatMessage(
          id: 'a2',
          role: 'assistant',
          content: 'Checking...',
          reasoningSections: ['thinking again'],
          toolCalls: [
            ToolCallData(
              id: 'tc2',
              name: 'calc',
              arguments: {'expr': '3+3'},
              status: ToolCallStatus.completed,
              result: '6',
            ),
          ],
        ),
      ];

      final conv = Conversation(
        id: 'conv-1',
        title: 'Test',
        messages: messages,
      );

      // Round-trip through toMap/fromMap
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.id, 'conv-1');
      expect(restored.messages.length, 4);

      // Verify ALL messages are present (not just the last one)
      expect(restored.messages[0].id, 'u1');
      expect(restored.messages[0].role, 'user');
      expect(restored.messages[0].content, 'What is 2+2?');

      expect(restored.messages[1].id, 'a1');
      expect(restored.messages[1].role, 'assistant');
      expect(restored.messages[1].content, 'Let me check...');
      expect(restored.messages[1].reasoningSections, isNotNull);
      expect(restored.messages[1].reasoningSections!.length, 1);
      expect(restored.messages[1].toolCalls, isNotNull);
      expect(restored.messages[1].toolCalls!.length, 1);

      expect(restored.messages[2].id, 'u2');
      expect(restored.messages[2].role, 'user');
      expect(restored.messages[2].content, 'What about 3+3?');

      expect(restored.messages[3].id, 'a2');
      expect(restored.messages[3].role, 'assistant');
      expect(restored.messages[3].content, 'Checking...');
      expect(restored.messages[3].reasoningSections, isNotNull);
      expect(restored.messages[3].reasoningSections!.length, 1);
      expect(restored.messages[3].toolCalls, isNotNull);
      expect(restored.messages[3].toolCalls!.length, 1);
    });

    test('updateMessages preserves all messages across multiple updates', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = [Conversation(id: 'conv-1', title: 'Test')];
            return notifier;
          }),
        ],
      );

      final notifier = container.read(conversationsProvider.notifier);

      // First update: 2 messages
      notifier.updateMessages('conv-1', [
        ChatMessage(id: 'u1', role: 'user', content: 'Hi'),
        ChatMessage(id: 'a1', role: 'assistant', content: 'Hello!'),
      ]);

      expect(notifier.state.first.messages.length, 2);
      expect(notifier.state.first.messages[0].role, 'user');
      expect(notifier.state.first.messages[1].role, 'assistant');

      // Second update: append 2 more (simulating second message)
      notifier.updateMessages('conv-1', [
        ChatMessage(id: 'u1', role: 'user', content: 'Hi'),
        ChatMessage(id: 'a1', role: 'assistant', content: 'Hello!'),
        ChatMessage(id: 'u2', role: 'user', content: 'How are you?'),
        ChatMessage(
            id: 'a2',
            role: 'assistant',
            content: 'Good!',
            reasoningSections: [
              'thinking'
            ],
            toolCalls: [
              ToolCallData(
                  id: 'tc',
                  name: 'test',
                  arguments: {},
                  status: ToolCallStatus.completed,
                  result: 'ok')
            ]),
      ]);

      // All 4 messages should be present
      expect(notifier.state.first.messages.length, 4);
      expect(notifier.state.first.messages[0].id, 'u1');
      expect(notifier.state.first.messages[1].id, 'a1');
      expect(notifier.state.first.messages[2].id, 'u2');
      expect(notifier.state.first.messages[3].id, 'a2');
      expect(notifier.state.first.messages[3].reasoningSections, isNotNull);
      expect(notifier.state.first.messages[3].toolCalls, isNotNull);
    });

    test(
        'periodic persist (partial) followed by final save gives correct final state',
        () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          conversationsProvider.overrideWith((ref) {
            final notifier = ConversationsNotifier(ref);
            notifier.state = [Conversation(id: 'conv-1', title: 'Test')];
            return notifier;
          }),
        ],
      );

      final notifier = container.read(conversationsProvider.notifier);

      // Step 1: Simulate periodic persist (partial stream data)
      // During streaming, _doPeriodicPersist saves the history + partial
      // assistant message.
      notifier.updateMessages('conv-1', [
        ChatMessage(id: 'u1', role: 'user', content: 'Calculate 2+2'),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'partial...',
          isStreaming: true,
          reasoningSections: ['thinking...'],
          toolCalls: [
            ToolCallData(
              id: 'tc',
              name: 'calc',
              arguments: {'expr': '2+2'},
              status: ToolCallStatus.running,
            ),
          ],
        ),
      ]);

      expect(notifier.state.first.messages.length, 2);

      // Step 2: Simulate final save (stream complete)
      // Final save overwrites with complete data
      notifier.updateMessages('conv-1', [
        ChatMessage(id: 'u1', role: 'user', content: 'Calculate 2+2'),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'The answer is 4',
          isStreaming: false,
          reasoningSections: ['thinking...', 'conclusion'],
          toolCalls: [
            ToolCallData(
              id: 'tc',
              name: 'calc',
              arguments: {'expr': '2+2'},
              status: ToolCallStatus.completed,
              result: '4',
            ),
          ],
        ),
      ]);

      // Final state should have the complete data
      final finalMsg = notifier.state.first.messages[1];
      expect(finalMsg.content, 'The answer is 4');
      expect(finalMsg.isStreaming, false);
      expect(finalMsg.reasoningSections!.length, 2);
      expect(finalMsg.toolCalls![0].status, ToolCallStatus.completed);
      expect(finalMsg.toolCalls![0].result, '4');
    });
  });
}
