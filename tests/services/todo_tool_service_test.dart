import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/todo_tool_service.dart';

void main() {
  // Reset state before each test
  setUp(() {
    TodoToolService.reset();
  });

  group('TodoToolService - tool definitions', () {
    test('exposes a single todowrite tool (read/write merged)', () {
      expect(TodoToolService.toolDefinitions, hasLength(1));
      expect(TodoToolService.toolDefinitions.single.name, 'todowrite');
      // 回归防护：todoread 已并入 todowrite（读写一体），不能再出现为独立工具。
      expect(
        TodoToolService.toolDefinitions.map((t) => t.name),
        isNot(contains('todoread')),
      );
    });
  });

  group('TodoToolService - handleTodo dispatcher', () {
    test('writes when todos is present', () async {
      final result = await TodoToolService.handleTodo({
        'todos': [
          {
            'content': 'Dispatcher task',
            'status': 'pending',
            'priority': 'high',
          },
        ],
      });

      expect(result, contains('1 todos'));
      final readResult = await TodoToolService.handleTodo({});
      expect(readResult, contains('Dispatcher task'));
    });

    test('reads when todos is omitted', () async {
      await TodoToolService.handleTodo({
        'todos': [
          {
            'content': 'Read via dispatcher',
            'status': 'in_progress',
            'priority': 'medium',
          },
        ],
      });

      final result = await TodoToolService.handleTodo({});
      expect(result, contains('Read via dispatcher'));
    });

    test('reads when todos is null (no destructive wipe)', () async {
      await TodoToolService.handleTodo({
        'todos': [
          {
            'content': 'Keep me',
            'status': 'pending',
            'priority': 'high',
          },
        ],
      });

      // 模型把可选数组序列化为 null 时应视为"读取"，绝不能清空列表。
      final result = await TodoToolService.handleTodo({'todos': null});
      expect(result, contains('Keep me'));
    });

    test('returns error for malformed non-List todos (no silent read)',
        () async {
      // 类型非法（如字符串）时返回错误提示而非静默读取，让模型自行修正。
      final result = await TodoToolService.handleTodo({'todos': 'not-a-list'});
      expect(result, contains('todos 参数必须是数组'));
    });
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

    test(
        'returns formatted response with active count excluding completed and cancelled',
        () async {
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
}
