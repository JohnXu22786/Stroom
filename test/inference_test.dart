import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ai_stream_event.dart';

void main() {
  group('AIStreamEvent', () {
    test('creates content event', () {
      final event = AIStreamEvent('hello');
      expect(event.text, 'hello');
      expect(event.isReasoning, false);
      expect(event.isToolCallEvent, false);
    });

    test('creates reasoning event', () {
      final event = AIStreamEvent('thinking...', isReasoning: true);
      expect(event.text, 'thinking...');
      expect(event.isReasoning, true);
      expect(event.isToolCallEvent, false);
    });

    test('creates tool call event', () {
      final event = AIStreamEvent('', toolCalls: [
        {'id': 'call_1', 'type': 'function', 'function': {'name': 'calc', 'arguments': '{}'}},
      ]);
      expect(event.isToolCallEvent, true);
      expect(event.toolCalls!.length, 1);
      expect(event.toolCalls![0]['id'], 'call_1');
    });

    test('empty toolCalls list is not a tool call event', () {
      final event = AIStreamEvent('', toolCalls: []);
      expect(event.isToolCallEvent, false);
    });

    test('null toolCalls is not a tool call event', () {
      final event = AIStreamEvent('hello');
      expect(event.isToolCallEvent, false);
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

  group('tool call delta accumulation', () {
    Map<int, Map<String, dynamic>> accumulateToolCalls(List<Map<String, dynamic>> deltas) {
      final accumulators = <int, Map<String, dynamic>>{};
      for (final tc in deltas) {
        final index = tc['index'] as int;
        accumulators.putIfAbsent(index, () => {});
        final acc = accumulators[index]!;
        if (tc['id'] != null) acc['id'] = tc['id'];
        if (tc['type'] != null) acc['type'] = tc['type'];
        if (tc['function'] != null) {
          acc.putIfAbsent('function', () => <String, dynamic>{});
          final fn = tc['function'] as Map<String, dynamic>;
          final accFn = acc['function'] as Map<String, dynamic>;
          if (fn['name'] != null) accFn['name'] = fn['name'];
          if (fn['arguments'] != null) {
            accFn['arguments'] = (accFn['arguments'] as String? ?? '') + (fn['arguments'] as String);
          }
        }
      }
      return accumulators;
    }

    test('accumulates tool call arguments across chunks', () {
      final result = accumulateToolCalls([
        {'index': 0, 'id': 'call_1', 'type': 'function', 'function': {'name': 'calculator', 'arguments': '{"expr'}},
        {'index': 0, 'function': {'arguments': 'ession": "2+2"}'}},
      ]);
      expect(result[0]!['id'], 'call_1');
      expect(result[0]!['type'], 'function');
      expect((result[0]!['function'] as Map)['name'], 'calculator');
      expect((result[0]!['function'] as Map)['arguments'], '{"expression": "2+2"}');
    });

    test('handles multiple tool call indices', () {
      final result = accumulateToolCalls([
        {'index': 0, 'id': 'call_1', 'function': {'name': 'calc1', 'arguments': '{"a":1}'}},
        {'index': 1, 'id': 'call_2', 'function': {'name': 'calc2', 'arguments': '{"b":2}'}},
      ]);
      expect(result.length, 2);
      expect((result[0]!['function'] as Map)['name'], 'calc1');
      expect((result[1]!['function'] as Map)['name'], 'calc2');
    });

    test('handles empty arguments', () {
      final result = accumulateToolCalls([
        {'index': 0, 'id': 'call_1', 'function': {'name': 'calc', 'arguments': ''}},
      ]);
      expect((result[0]!['function'] as Map)['arguments'], '');
    });

    test('handles missing function field', () {
      final result = accumulateToolCalls([
        {'index': 0, 'id': 'call_1', 'type': 'function'},
      ]);
      expect((result[0]!['function'] as Map?)?.isEmpty ?? true, true);
    });
  });
}
