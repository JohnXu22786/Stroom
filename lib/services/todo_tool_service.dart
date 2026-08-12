import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/tool_call.dart';

// ============================================================================
// Todo 工具服务层
//
// 参照 Anomalyco/OpenCode 的 todowrite 内置工具（todoread 已于上游移除，
// 读取能力并入同一工具），改为纯 Dart 实现，作为内置 MCP 工具供 LLM 调用。
//
// 功能（单一 todowrite 工具，读写一体）：
// - 写入：传入 todos 参数 → 覆盖写入待办列表（全量替换，增量操作由 LLM 自行处理）
// - 读取：省略 todos 参数 → 读取当前会话的待办列表
// ============================================================================

/// Todo 工具的服务层，管理内存中的待办事项并提供处理函数
class TodoToolService {
  TodoToolService._();

  /// 内存中的待办事项列表（按 position 排序）
  static final List<TodoItem> _todos = [];

  /// 工具定义列表（单一 todowrite 工具，读写一体）
  static final List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: 'todowrite',
      description: '创建、读取并管理待办事项列表。'
          '传入 todos（完整的待办事项列表）时覆盖写入，系统将替换所有现有事项；'
          '省略 todos 参数时读取当前待办事项列表。各事项包含：'
          'content（任务描述）、status（状态: pending/in_progress/completed/cancelled）、'
          'priority（优先级: high/medium/low）。'
          '适用于 3 个以上步骤的复杂任务管理。',
      parameters: {
        'type': 'object',
        'properties': {
          'todos': {
            'type': 'array',
            'description': '待办事项列表（全量替换）。省略该参数时读取当前待办列表。',
            'items': {
              'type': 'object',
              'properties': {
                'content': {
                  'type': 'string',
                  'description': '任务描述',
                },
                'status': {
                  'type': 'string',
                  'description':
                      '任务状态: pending（待处理）, in_progress（进行中）, completed（已完成）, cancelled（已取消）',
                  'enum': ['pending', 'in_progress', 'completed', 'cancelled'],
                },
                'priority': {
                  'type': 'string',
                  'description': '优先级: high（高）, medium（中）, low（低）',
                  'enum': ['high', 'medium', 'low'],
                },
              },
              'required': ['content'],
            },
          },
        },
        'required': <String>[],
      },
    ),
  ];

  /// 重置状态（用于测试）
  @visibleForTesting
  static void reset() {
    _todos.clear();
  }

  /// 处理 todowrite 调用（读写一体入口）。
  ///
  /// [args] 的 `todos` 为 List 时执行覆盖写入；`todos` 缺失或为 null
  /// （null 视为省略）时读取当前待办列表，避免模型把可选数组序列化成
  /// null 时误清空整个列表。`todos` 存在但类型非法（非 List）时返回
  /// 错误提示，让模型自行修正，而不是静默走读取分支。
  static Future<String> handleTodo(Map<String, dynamic> args) async {
    final todos = args['todos'];
    if (todos == null) {
      return handleTodoRead(args);
    }
    if (todos is List) {
      return handleTodoWrite(args);
    }
    return '错误: todos 参数必须是数组（省略或传 null 表示读取待办列表）';
  }

  /// 处理 todowrite 调用
  ///
  /// [args] 包含：
  ///   - todos (List): 完整的待办事项列表，每个元素包含 content、status、priority
  static Future<String> handleTodoWrite(Map<String, dynamic> args) async {
    final todosRaw = args['todos'] as List<dynamic>? ?? [];

    _todos.clear();
    for (var i = 0; i < todosRaw.length; i++) {
      final item = todosRaw[i];
      if (item is Map<String, dynamic>) {
        _todos.add(TodoItem(
          content: (item['content'] as String?) ?? '',
          status: (item['status'] as String?) ?? 'pending',
          priority: (item['priority'] as String?) ?? 'medium',
          position: i,
        ));
      }
    }

    final activeCount = _todos
        .where((t) => t.status != 'completed' && t.status != 'cancelled')
        .length;
    final jsonStr = jsonEncode(_todos.map((t) => t.toJson()).toList());

    return '$activeCount todos\n\n```json\n$jsonStr\n```';
  }

  /// 处理读取分支（todos 缺失或为 null 时由 [handleTodo] 分发到这里）
  static Future<String> handleTodoRead(Map<String, dynamic> args) async {
    if (_todos.isEmpty) {
      return '当前没有待办事项。';
    }

    final activeCount = _todos
        .where((t) => t.status != 'completed' && t.status != 'cancelled')
        .length;
    final jsonStr = jsonEncode(_todos.map((t) => t.toJson()).toList());

    return '$activeCount todos\n\n```json\n$jsonStr\n```';
  }
}

/// Todo 事项数据模型
class TodoItem {
  final String content;
  final String status;
  final String priority;
  final int position;

  const TodoItem({
    required this.content,
    this.status = 'pending',
    this.priority = 'medium',
    this.position = 0,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'status': status,
        'priority': priority,
        'position': position,
      };
}
