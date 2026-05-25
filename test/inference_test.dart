import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';

void main() {
  group('AIStreamEvent', () {
    test('creates content event', () {
      final event = AIStreamEvent('hello');
      expect(event.text, 'hello');
      expect(event.isReasoning, false);
    });

    test('creates reasoning event', () {
      final event = AIStreamEvent('thinking...', isReasoning: true);
      expect(event.text, 'thinking...');
      expect(event.isReasoning, true);
    });
  });

  group('reasoning params in _buildBody', () {
    Map<String, dynamic> buildBody({bool reasoning = false}) {
      return {
        'model': 'test-model',
        'messages': [{'role': 'user', 'content': 'hi'}],
        'max_tokens': 4096,
        'temperature': 0.7,
        'stream': false,
        if (reasoning)
          'thinking': {'type': 'enabled'},
      };
    }

    test('adds thinking params when reasoning is enabled', () {
      final body = buildBody(reasoning: true);
      expect(body['thinking'], {'type': 'enabled'});
    });

    test('does not add thinking params when reasoning is disabled', () {
      final body = buildBody(reasoning: false);
      expect(body.containsKey('thinking'), isFalse);
    });
  });

  group('delta parsing', () {
    AIStreamEvent? parseDelta(Map<String, dynamic> delta, {bool reasoning = false}) {
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) {
        return AIStreamEvent(content);
      }
      if (reasoning) {
        final reasoningContent = delta['reasoning_content'] as String?;
        if (reasoningContent != null && reasoningContent.isNotEmpty) {
          return AIStreamEvent(reasoningContent, isReasoning: true);
        }
      }
      return null;
    }

    test('parses content from delta', () {
      final event = parseDelta({'content': 'hello'})!;
      expect(event.text, 'hello');
      expect(event.isReasoning, false);
    });

    test('parses reasoning_content when reasoning enabled', () {
      final event = parseDelta({'reasoning_content': 'thinking...'}, reasoning: true)!;
      expect(event.text, 'thinking...');
      expect(event.isReasoning, true);
    });

    test('does not parse reasoning_content when reasoning disabled', () {
      final event = parseDelta({'reasoning_content': 'thinking...'}, reasoning: false);
      expect(event, isNull);
    });

    test('parses content even when reasoning_content is present', () {
      final event = parseDelta({'content': 'answer', 'reasoning_content': 'thinking...'}, reasoning: true)!;
      expect(event.text, 'answer');
      expect(event.isReasoning, false);
    });

    test('skips empty content', () {
      expect(parseDelta({'content': ''}), isNull);
      expect(parseDelta({'reasoning_content': ''}, reasoning: true), isNull);
    });

    test('skips null content', () {
      expect(parseDelta({'content': null}), isNull);
      expect(parseDelta({'reasoning_content': null}, reasoning: true), isNull);
    });
  });
}
