import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/todo_tool_service.dart';

void main() {
  // Reset state before each test
  setUp(() {
    TodoToolService.reset();
  });

  group('TodoToolService - todowrite', () {
    test('creates new todos from scratch', () async {
      final result = await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Task 1',
            'status': 'pending',
            'priority': 'high',
          },
          {
            'content': 'Task 2',
            'status': 'in_progress',
            'priority': 'medium',
          },
        ],
      });

      // Check response contains count
      expect(result, contains('2 todos'));

      // Verify state was persisted
      final readResult = await TodoToolService.handleTodoRead({});
      expect(readResult, contains('Task 1'));
      expect(readResult, contains('Task 2'));
    });

    test('replaces full list on subsequent calls', () async {
      // First write
      await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Task 1',
            'status': 'pending',
            'priority': 'high',
          },
        ],
      });

      // Second write replaces all
      final result = await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Task A',
            'status': 'completed',
            'priority': 'low',
          },
        ],
      });

      expect(result, contains('0 todos')); // completed tasks don't count

      // Old task should be gone
      final readResult = await TodoToolService.handleTodoRead({});
      expect(readResult, contains('Task A'));
      expect(readResult, isNot(contains('Task 1')));
    });

    test('returns formatted response with active count excluding completed and cancelled', () async {
      final result = await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Active task',
            'status': 'in_progress',
            'priority': 'high',
          },
          {
            'content': 'Done task',
            'status': 'completed',
            'priority': 'medium',
          },
          {
            'content': 'Cancelled task',
            'status': 'cancelled',
            'priority': 'low',
          },
        ],
      });

      // Only 1 active task: Active task (completed and cancelled are excluded)
      expect(result, contains('1 todos'));
      expect(result, contains('Active task'));
      expect(result, contains('Done task')); // still in the list
      expect(result, contains('Cancelled task')); // still in the list
    });

    test('handles missing optional fields gracefully', () async {
      // Missing required fields should not crash
      final result = await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Task with defaults',
            // status and priority missing
          },
        ],
      });

      expect(result, contains('1 todos'));
      final readResult = await TodoToolService.handleTodoRead({});
      expect(readResult, contains('Task with defaults'));
    });
  });

  group('TodoToolService - todoread', () {
    test('returns current todos', () async {
      await TodoToolService.handleTodoWrite({
        'todos': [
          {
            'content': 'Read task',
            'status': 'pending',
            'priority': 'high',
          },
        ],
      });

      final result = await TodoToolService.handleTodoRead({});
      expect(result, contains('Read task'));
      expect(result, contains('pending'));
      expect(result, contains('high'));
    });

    test('returns empty message when no todos exist', () async {
      final result = await TodoToolService.handleTodoRead({});
      expect(result, contains('当前没有待办事项'));
    });

    test('returns empty message after writing empty list', () async {
      await TodoToolService.handleTodoWrite({'todos': []});
      final result = await TodoToolService.handleTodoRead({});
      expect(result, contains('当前没有待办事项'));
    });
  });

  group('TodoToolService - tool definitions', () {
    test('has correct tool definitions structure', () {
      final defs = TodoToolService.toolDefinitions;

      expect(defs.length, equals(2));

      // todowrite
      final writeDef = defs.firstWhere((d) => d.name == 'todowrite');
      expect(writeDef.name, equals('todowrite'));
      expect(writeDef.description, isNotEmpty);
      expect(writeDef.parameters['type'], equals('object'));
      expect(
        (writeDef.parameters['properties'] as Map)['todos'],
        isNotNull,
      );

      // todoread
      final readDef = defs.firstWhere((d) => d.name == 'todoread');
      expect(readDef.name, equals('todoread'));
      expect(readDef.description, isNotEmpty);
    });

    test('todowrite definition accepts todo items with content/status/priority',
        () {
      final writeDef =
          TodoToolService.toolDefinitions.firstWhere((d) => d.name == 'todowrite');
      final todoProperty = (writeDef.parameters['properties'] as Map)['todos'];
      expect(todoProperty, isNotNull);

      // Verify the todos array items schema
      final items = (todoProperty as Map)['items'] as Map;
      final itemProperties = items['properties'] as Map;
      expect(itemProperties.containsKey('content'), isTrue);
      expect(itemProperties.containsKey('status'), isTrue);
      expect(itemProperties.containsKey('priority'), isTrue);
    });
  });

  group('TodoToolService - data model', () {
    test('todo item defaults to pending status and medium priority', () {
      final item = TodoItem(content: 'Test task');
      expect(item.content, equals('Test task'));
      expect(item.status, equals('pending'));
      expect(item.priority, equals('medium'));
    });

    test('todo item serializes to JSON correctly', () {
      final item = TodoItem(
        content: 'Test',
        status: 'in_progress',
        priority: 'high',
      );
      final map = item.toJson();
      expect(map['content'], equals('Test'));
      expect(map['status'], equals('in_progress'));
      expect(map['priority'], equals('high'));
    });
  });
}
