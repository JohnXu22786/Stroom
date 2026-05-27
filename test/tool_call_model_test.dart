import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ToolCallData', () {
    test('creates with default status pending', () {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );
      expect(data.id, 'call_1');
      expect(data.name, 'calculator');
      expect(data.arguments, {'expression': '2+2'});
      expect(data.status, ToolCallStatus.pending);
      expect(data.result, isNull);
    });

    test('copyWith updates status', () {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );
      final running = data.copyWith(status: ToolCallStatus.running);
      expect(running.status, ToolCallStatus.running);
      expect(running.result, isNull);
      expect(running.id, 'call_1');
    });

    test('copyWith updates result', () {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
        status: ToolCallStatus.running,
      );
      final completed = data.copyWith(
        status: ToolCallStatus.completed,
        result: '4',
      );
      expect(completed.status, ToolCallStatus.completed);
      expect(completed.result, '4');
    });

    test('copyWith does not mutate original', () {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );
      data.copyWith(status: ToolCallStatus.completed, result: '4');
      expect(data.status, ToolCallStatus.pending);
      expect(data.result, isNull);
    });

    test('preserves arguments after copyWith', () {
      final data = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );
      final updated = data.copyWith(status: ToolCallStatus.running);
      expect(updated.arguments, {'expression': '2+2'});
    });
  });

  group('ToolDefinition', () {
    test('toJson produces correct format', () {
      final def = ToolDefinition(
        name: 'calculator',
        description: 'Evaluate a math expression',
        parameters: {
          'type': 'object',
          'properties': {
            'expression': {'type': 'string'},
          },
          'required': ['expression'],
        },
      );
      final json = def.toJson();
      expect(json, {
        'type': 'function',
        'function': {
          'name': 'calculator',
          'description': 'Evaluate a math expression',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {'type': 'string'},
            },
            'required': ['expression'],
          },
        },
      });
    });
  });

  group('ChatEvent sealed class', () {
    test('TextEvent holds text', () {
      final event = TextEvent('hello');
      expect(event.text, 'hello');
    });

    test('ToolCallStartEvent holds toolCall', () {
      final toolCall = ToolCallData(
        id: 'call_1',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );
      final event = ToolCallStartEvent(toolCall);
      expect(event.toolCall.name, 'calculator');
      expect(event.toolCall.status, ToolCallStatus.pending);
    });

    test('ToolCallCompleteEvent holds toolCallId and result', () {
      final event = ToolCallCompleteEvent('call_1', '4');
      expect(event.toolCallId, 'call_1');
      expect(event.result, '4');
    });

    test('Events are distinct types', () {
      final text = TextEvent('hi');
      final start = ToolCallStartEvent(
        ToolCallData(id: 'c1', name: 'calc', arguments: {}),
      );
      final complete = ToolCallCompleteEvent('c1', '4');

      expect(text, isA<TextEvent>());
      expect(start, isA<ToolCallStartEvent>());
      expect(complete, isA<ToolCallCompleteEvent>());
    });
  });
}
