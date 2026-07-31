import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/context_manager.dart';
import 'package:stroom/utils/token_estimator.dart';

// ============================================================================
// ContextManager 测试（工具 prune / 估算）
// ============================================================================
//
// 覆盖行为：
// 1. 阈值：可压缩量不足 20K 不执行（返回原引用）；超过才落印
// 2. 保护：最近 2 轮用户消息内的工具结果不压缩
// 3. 边界：遇到已压缩条目即停止扫描（不重复处理）
// 4. 双写一致性：toolCalls 与 blocks 同步压缩
// 5. 序列化：compactedAt 往返
// 6. 估算：estimateHistoryTokens 与 estimateTokens 行为

/// 生成一个指定大小（字符数）的工具结果。
String _bigResult(int chars) => 'x' * chars;

ChatMessage _assistantWithTool({
  required String id,
  required String result,
  ToolCallStatus status = ToolCallStatus.completed,
  DateTime? compactedAt,
}) {
  final tc = ToolCallData(
    id: id,
    name: 'web_search',
    arguments: const {'q': 'test'},
    status: status,
    result: result,
    compactedAt: compactedAt,
  );
  return ChatMessage(
    role: 'assistant',
    content: '回答',
    toolCalls: [tc],
    blocks: [
      TextBlock(text: '回答'),
      ToolCallBlock(
        id: id,
        name: 'web_search',
        arguments: const {'q': 'test'},
        status: status,
        result: result,
        compactedAt: compactedAt,
      ),
    ],
  );
}

void main() {
  group('estimateTokens', () {
    test('空串为 0', () {
      expect(estimateTokens(''), 0);
    });

    test('ASCII 每 4 字符约 1 token', () {
      expect(estimateTokens('abcd'), 1);
      expect(estimateTokens('abcdefgh'), 2);
    });

    test('CJK 加权（每 1.5 字符约 1 token）', () {
      // 3 个汉字 → 2 tokens（ceil(3 * 2/3)）
      expect(estimateTokens('你好吗'), 2);
    });
  });

  group('pruneToolResults', () {
    test('可压缩量不足阈值：返回原引用，不修改历史', () {
      final history = [
        ChatMessage(role: 'user', content: 'q'),
        _assistantWithTool(id: 't1', result: _bigResult(100)),
      ];
      final result = ContextManager.pruneToolResults(history);
      expect(identical(result, history), isTrue);
      expect(result[1].toolCalls![0].compactedAt, isNull);
      expect(result[1].toolCalls![0].result, _bigResult(100));
    });

    test('超过阈值：旧工具结果被替换为占位文本并标记 compactedAt', () {
      // 200000 字符 ≈ 50000 token > 40000 保护线；
      // 旧工具在最近 2 轮用户消息之前，可被扫描到
      final history = [
        _assistantWithTool(id: 'old', result: _bigResult(200000)),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
        _assistantWithTool(id: 'new', result: _bigResult(100)),
      ];
      final result = ContextManager.pruneToolResults(history);
      // 新工具结果保护（最近 2 轮用户消息内）
      expect(result[3].toolCalls![0].compactedAt, isNull);
      expect(result[3].toolCalls![0].result, _bigResult(100));
      // 旧工具结果压缩
      expect(result[0].toolCalls![0].compactedAt, isNotNull);
      expect(
        result[0].toolCalls![0].result,
        kCompactedToolResultPlaceholder,
      );
      // blocks 同步压缩（双写一致性）
      final block = result[0].blocks!.whereType<ToolCallBlock>().single;
      expect(block.compactedAt, isNotNull);
      expect(block.result, kCompactedToolResultPlaceholder);
    });

    test('保护最近 tailUserTurns 轮用户消息内的工具', () {
      final history = [
        _assistantWithTool(id: 'very_old', result: _bigResult(200000)),
        ChatMessage(role: 'user', content: '第一轮'),
        _assistantWithTool(id: 'old_round', result: _bigResult(200000)),
        ChatMessage(role: 'user', content: '第二轮'),
        _assistantWithTool(id: 'recent', result: _bigResult(200000)),
      ];
      final result = ContextManager.pruneToolResults(history);
      // 最近 2 轮用户消息之后的消息都保护
      expect(result[4].toolCalls![0].compactedAt, isNull);
      expect(result[2].toolCalls![0].compactedAt, isNull);
      // 更早的压缩
      expect(result[0].toolCalls![0].compactedAt, isNotNull);
    });

    test('遇到已压缩条目立即停止扫描（不重复处理更早消息）', () {
      final history = [
        _assistantWithTool(id: 'even_older', result: _bigResult(200000)),
        _assistantWithTool(
          id: 'already_compacted',
          result: _bigResult(60000),
          compactedAt: DateTime(2024),
        ),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ];
      final result = ContextManager.pruneToolResults(history);
      // 遇到已压缩条目后停止：更早的消息（even_older）不被压缩
      expect(result[0].toolCalls![0].compactedAt, isNull);
      expect(result[0].toolCalls![0].result, _bigResult(200000));
      // 对照组：没有已压缩条目时 even_older 会被压缩
      final noBoundary = ContextManager.pruneToolResults(
        history.skip(1).toList(),
      );
      expect(noBoundary[0].toolCalls![0].compactedAt, isNotNull);
    });

    test('非 completed 状态的工具结果不参与压缩', () {
      final history = [
        _assistantWithTool(id: 'done', result: _bigResult(200000)),
        _assistantWithTool(
          id: 'running',
          result: _bigResult(200000),
          status: ToolCallStatus.running,
        ),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ];
      final result = ContextManager.pruneToolResults(history);
      expect(result[0].toolCalls![0].compactedAt, isNotNull);
      // running 状态不压缩（即使位于可扫描区）
      expect(result[1].toolCalls![0].compactedAt, isNull);
    });

    test('自定义阈值参数生效', () {
      // 5000 字符 ≈ 1250 token
      final history = [
        _assistantWithTool(id: 'old', result: _bigResult(5000)),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ];
      // 自定义阈值（minimum 1000, protect 500）→ 压缩
      final pruned = ContextManager.pruneToolResults(
        history,
        pruneMinimumTokens: 1000,
        pruneProtectTokens: 500,
      );
      expect(pruned[0].toolCalls![0].compactedAt, isNotNull);
      // 默认阈值（minimum 20000）下不压缩
      final notPruned = ContextManager.pruneToolResults(history);
      expect(notPruned[0].toolCalls![0].compactedAt, isNull);
    });
  });

  group('compactedAt 序列化', () {
    test('ToolCallData 往返', () {
      final tc = ToolCallData(
        id: 't1',
        name: 'web_search',
        arguments: const {'q': 'x'},
        status: ToolCallStatus.completed,
        result: kCompactedToolResultPlaceholder,
        compactedAt: DateTime(2026, 7, 31, 12, 30),
      );
      final restored = ToolCallData.fromMap(tc.toMap());
      expect(restored.compactedAt, DateTime(2026, 7, 31, 12, 30));
      expect(restored.result, kCompactedToolResultPlaceholder);
    });

    test('ToolCallData 无 compactedAt 时不序列化该字段（旧数据兼容）', () {
      final tc = ToolCallData(
        id: 't1',
        name: 'web_search',
        arguments: const {},
        result: 'r',
      );
      expect(tc.toMap().containsKey('compactedAt'), isFalse);
      expect(
          ToolCallData.fromMap({'id': 'x', 'name': 'n'}).compactedAt, isNull);
    });

    test('ToolCallBlock 往返', () {
      final block = ToolCallBlock(
        id: 't1',
        name: 'web_search',
        result: kCompactedToolResultPlaceholder,
        compactedAt: DateTime(2026, 7, 31),
      );
      final restored = ToolCallBlock.fromMap(block.toMap());
      expect(restored.compactedAt, DateTime(2026, 7, 31));
    });
  });

  group('estimateHistoryTokens', () {
    test('包含 system、消息、工具定义', () {
      final history = [
        ChatMessage(role: 'user', content: '你好世界'),
        _assistantWithTool(id: 't', result: 'abcd'),
      ];
      final total = ContextManager.estimateHistoryTokens(
        history,
        assistantPrompt: '系统提示',
        tools: [
          const ToolDefinition(
            name: 'web_search',
            description: '搜索',
            parameters: {'type': 'object'},
          ),
        ],
      );
      expect(total, greaterThan(0));
    });

    test('已压缩的工具结果按占位符估算（体积大幅减小）', () {
      final big = _assistantWithTool(id: 't', result: _bigResult(200000));
      final before = ContextManager.estimateHistoryTokens([big]);
      final pruned = ContextManager.pruneToolResults([
        big,
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ]).first;
      final after = ContextManager.estimateHistoryTokens([pruned]);
      expect(after, lessThan(before));
    });
  });
}
