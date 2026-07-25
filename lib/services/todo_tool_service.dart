import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/tool_call.dart';

// ============================================================================
// Todo 工具服务层
//
// 参照 Anomalyco/OpenCode 的 todowrite / todoread 内置工具，
// 改为纯 Dart 实现，作为内置 MCP 工具供 LLM 调用。
//
// 功能：
// - todowrite：覆盖写入待办列表（全量替换，增量操作由 LLM 自行处理）
// - todoread：读取当前会话的待办列表
// ============================================================================

/// Todo 工具的服务层，管理内存中的待办事项并提供处理函数
class TodoToolService {
  TodoToolService._();

  /// 内存中的待办事项列表（按 position 排序）
  static final List<TodoItem> _todos = [];

  /// 工具定义列表
  static final List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: 'todowrite',
      description:
          '创建并管理待办事项列表。每次调用时需提供完整的待办事项列表，'
          '系统将替换所有现有事项。各事项包含：'
          'content（任务描述）、status（状态: pending/in_progress/completed/cancelled）、'
          'priority（优先级: high/medium/low）。'
          '适用于 3 个以上步骤的复杂任务管理。',
      parameters: {
        'type': 'object',
        'properties': {
          'todos': {
            'type': 'array',
            'description': '待办事项列表（全量替换）',
            'items': {
              'type': 'object',
              'properties': {
                'content': {
                  'type': 'string',
                  'description': '任务描述',
                },
                'status': {
                  'type': 'string',
                  'description': '任务状态: pending（待处理）, in_progress（进行中）, completed（已完成）, cancelled（已取消）',
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
        'required': ['todos'],
      },
    ),
    ToolDefinition(
      name: 'todoread',
      description: '读取当前的待办事项列表。返回所有待办事项及其状态和优先级信息。',
      parameters: {
        'type': 'object',
        'properties': {},
        'required': <String>[],
      },
    ),
  ];

  /// 重置状态（用于测试）
  @visibleForTesting
  static void reset() {
    _todos.clear();
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

    final activeCount = _todos.where((t) => t.status != 'completed' && t.status != 'cancelled').length;
    final jsonStr = jsonEncode(_todos.map((t) => t.toJson()).toList());

    return '$activeCount todos\n\n```json\n$jsonStr\n```';
  }

  /// 处理 todoread 调用
  static Future<String> handleTodoRead(Map<String, dynamic> args) async {
    if (_todos.isEmpty) {
      return '当前没有待办事项。';
    }

    final activeCount = _todos.where((t) => t.status != 'completed' && t.status != 'cancelled').length;
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
