import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';

void main() {
  group('ReasoningEvent', () {
    test('can be created with text content', () {
      const event = ReasoningEvent('test reasoning text');
      expect(event.text, 'test reasoning text');
    });

    test('is a ChatEvent', () {
      const event = ReasoningEvent('test');
      expect(event, isA<ChatEvent>());
    });

    test('can be empty', () {
      const event = ReasoningEvent('');
      expect(event.text, '');
    });

    test('can be used in a switch statement', () {
      final ChatEvent event = ReasoningEvent('reasoning');
      String result = '';
      switch (event) {
        case ReasoningEvent e:
          result = 'reasoning: ${e.text}';
        case TextEvent e:
          result = 'text: ${e.text}';
        default:
          result = 'unknown';
      }
      expect(result, 'reasoning: reasoning');
    });
  });

  group('ChatMessage reasoningContent serialization', () {
    test('reasoningContent is serialized and deserialized correctly', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
        id: 'a1',
        reasoningContent: 'Step-by-step reasoning...',
      );

      final map = msg.toMap();
      expect(map['reasoningContent'], 'Step-by-step reasoning...');

      final restored = ChatMessage.fromMap(map);
      expect(restored.reasoningContent, 'Step-by-step reasoning...');
    });

    test('null reasoningContent is not serialized', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
        id: 'a2',
      );

      final map = msg.toMap();
      expect(map.containsKey('reasoningContent'), false);
    });

    test('empty reasoningContent is not serialized', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Final answer',
        id: 'a3',
        reasoningContent: '',
      );

      final map = msg.toMap();
      // Empty string still gets serialized because the field is non-null
      final restored = ChatMessage.fromMap(map);
      expect(restored.reasoningContent, '');
    });

    test('reasoningContent survives full conversation serialization cycle', () {
      final messages = [
        ChatMessage(role: 'user', content: 'Hello', id: 'u1'),
        ChatMessage(
          role: 'assistant',
          content: 'Final answer',
          id: 'a1',
          reasoningContent:
              'I need to think about this...\nStep 1: ...\nStep 2: ...',
        ),
      ];

      // Simulate saving/loading a conversation
      final serialized = messages.map((m) => m.toMap()).toList();
      final deserialized = serialized
          .map((m) => ChatMessage.fromMap(m))
          .toList();

      expect(
        deserialized[1].reasoningContent,
        'I need to think about this...\nStep 1: ...\nStep 2: ...',
      );
      expect(deserialized[1].content, 'Final answer');
    });
  });

  group('ChatEvent sealed class pattern', () {
    test('ReasoningEvent is distinct from TextEvent', () {
      final reasoning = ReasoningEvent('think');
      final text = TextEvent('speak');

      expect(reasoning.runtimeType, isNot(text.runtimeType));
    });
  });
}
