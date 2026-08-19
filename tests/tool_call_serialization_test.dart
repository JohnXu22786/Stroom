import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  group('ToolCallData serialization', () {
    test('toMap includes all fields', () {
      final toolCall = ToolCallData(
        id: 'call_abc123',
        name: 'get_weather',
        arguments: {'location': 'Beijing', 'unit': 'celsius'},
        status: ToolCallStatus.completed,
        result: '晴, 25°C',
      );

      final map = toolCall.toMap();
      expect(map['id'], 'call_abc123');
      expect(map['name'], 'get_weather');
      expect(map['arguments'], {'location': 'Beijing', 'unit': 'celsius'});
      expect(map['status'], 'completed');
      expect(map['result'], '晴, 25°C');
    });

    test('toMap omits result when null', () {
      final toolCall = ToolCallData(
        id: 'call_def456',
        name: 'search_docs',
        arguments: {'query': 'Flutter'},
        status: ToolCallStatus.running,
      );

      final map = toolCall.toMap();
      expect(map['id'], 'call_def456');
      expect(map['name'], 'search_docs');
      expect(map['status'], 'running');
      expect(map.containsKey('result'), false);
    });

    test('fromMap restores all fields', () {
      final map = <String, dynamic>{
        'id': 'call_xyz789',
        'name': 'calculate',
        'arguments': {'expression': '2 + 2'},
        'status': 'completed',
        'result': '4',
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.id, 'call_xyz789');
      expect(toolCall.name, 'calculate');
      expect(toolCall.arguments, {'expression': '2 + 2'});
      expect(toolCall.status, ToolCallStatus.completed);
      expect(toolCall.result, '4');
    });

    test('fromMap handles missing result gracefully', () {
      final map = <String, dynamic>{
        'id': 'call_no_result',
        'name': 'ping',
        'arguments': <String, dynamic>{},
        'status': 'running',
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.id, 'call_no_result');
      expect(toolCall.result, isNull);
      expect(toolCall.status, ToolCallStatus.running);
    });

    test('fromMap handles invalid status gracefully (defaults to pending)', () {
      final map = <String, dynamic>{
        'id': 'call_bad_status',
        'name': 'test',
        'arguments': <String, dynamic>{},
        'status': 'unknown_status',
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.status, ToolCallStatus.pending);
    });

    test('fromMap handles null status gracefully', () {
      final map = <String, dynamic>{
        'id': 'call_null_status',
        'name': 'test',
        'arguments': <String, dynamic>{},
        'status': null,
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.status, ToolCallStatus.pending);
    });

    test('fromMap handles null arguments gracefully', () {
      final map = <String, dynamic>{
        'id': 'call_null_args',
        'name': 'test',
        'arguments': null,
        'status': 'pending',
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.arguments, isEmpty);
    });

    test('fromMap handles non-Map arguments gracefully', () {
      final map = <String, dynamic>{
        'id': 'call_nonmap_args',
        'name': 'test',
        'arguments': 'not-a-map',
        'status': 'pending',
      };

      final toolCall = ToolCallData.fromMap(map);
      expect(toolCall.arguments, isEmpty);
    });

    test('serialization round-trip preserves all fields', () {
      final original = ToolCallData(
        id: 'call_roundtrip',
        name: 'translate',
        arguments: {'text': 'Hello', 'target': 'zh'},
        status: ToolCallStatus.error,
        result: 'Translation API timeout',
      );

      final map = original.toMap();
      final restored = ToolCallData.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.arguments, original.arguments);
      expect(restored.status, original.status);
      expect(restored.result, original.result);
    });

    test('serialization round-trip preserves copyWith modifications', () {
      final original = ToolCallData(
        id: 'call_cw',
        name: 'search',
        arguments: {'q': 'flutter'},
        status: ToolCallStatus.running,
      );

      final updated = original.copyWith(
        status: ToolCallStatus.completed,
        result: 'Found 3 results',
      );

      final map = updated.toMap();
      final restored = ToolCallData.fromMap(map);
      expect(restored.status, ToolCallStatus.completed);
      expect(restored.result, 'Found 3 results');
      expect(restored.id, 'call_cw');
    });
  });
}
