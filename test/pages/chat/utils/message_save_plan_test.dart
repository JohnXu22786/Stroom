import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat/utils/message_save_plan.dart';

ToolCallData _tc(String id) => ToolCallData(
      id: id,
      name: 'web_search',
      arguments: {'query': 'x'},
      status: ToolCallStatus.completed,
    );

void main() {
  group('buildMessageSavePlan', () {
    test('plain text reply without tool calls: single scope, full text', () {
      final plan = buildMessageSavePlan(
        segments: [
          TextSegment('直接回答的内容，没有任何工具调用。'),
        ],
        fallbackText: '直接回答的内容，没有任何工具调用。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      expect(plan.fullMarkdown, '直接回答的内容，没有任何工具调用。');
      expect(plan.lastMarkdown, plan.fullMarkdown);
    });

    test('multi-step tools without text between steps: single scope', () {
      // R0→TC0→R1→TC1→R2→final reply（工具调用之间只有思考链，没有回话）
      final plan = buildMessageSavePlan(
        segments: [
          ReasoningSegment(sectionIndex: 0),
          ToolCallSegment(_tc('1')),
          ReasoningSegment(sectionIndex: 1),
          ToolCallSegment(_tc('2')),
          ReasoningSegment(sectionIndex: 2),
          TextSegment('最后的正式回复。'),
        ],
        fallbackText: '最后的正式回复。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      expect(plan.textParts, ['最后的正式回复。']);
      expect(plan.fullMarkdown, '最后的正式回复。');
    });

    test('multi-step tools with text between steps: fullOrLast scope', () {
      final plan = buildMessageSavePlan(
        segments: [
          ReasoningSegment(sectionIndex: 0),
          TextSegment('开始搜索。'),
          ToolCallSegment(_tc('1')),
          ReasoningSegment(sectionIndex: 1),
          TextSegment('找到了相关结果。'),
          ToolCallSegment(_tc('2')),
          ReasoningSegment(sectionIndex: 2),
          TextSegment('最终总结。'),
        ],
        fallbackText: '最终总结。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.fullOrLast);
      // 顺序保持，每部分之间正是 \n\n 换段（不是单个换行）
      expect(
        plan.fullMarkdown,
        '开始搜索。\n\n找到了相关结果。\n\n最终总结。',
      );
      expect(plan.fullMarkdown.contains('\n\n'), isTrue);
    });

    test('lastMarkdown returns only the last formal reply', () {
      final plan = buildMessageSavePlan(
        segments: [
          TextSegment('第一步反馈。'),
          ToolCallSegment(_tc('1')),
          TextSegment('最终回复。'),
        ],
        fallbackText: '最终回复。',
      );

      expect(plan, isNotNull);
      expect(plan!.lastMarkdown, '最终回复。');
      expect(plan.lastMarkdown, isNot(contains('第一步反馈')));
    });

    test('no text anywhere (tools/thinking only): returns null', () {
      final plan = buildMessageSavePlan(
        segments: [
          ReasoningSegment(sectionIndex: 0),
          ToolCallSegment(_tc('1')),
          ToolCallSegment(_tc('2')),
        ],
        fallbackText: '  ',
      );

      expect(plan, isNull);
    });

    test('empty segments fall back to message text', () {
      final plan = buildMessageSavePlan(
        segments: const [],
        fallbackText: '旧格式消息的完整文本。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      expect(plan.fullMarkdown, '旧格式消息的完整文本。');
    });

    test('text parts are trimmed and empty parts are filtered', () {
      final plan = buildMessageSavePlan(
        segments: [
          TextSegment('  第一段。  '),
          TextSegment('   '),
          TextSegment('\n\n第二段。\n'),
        ],
        fallbackText: '',
      );

      expect(plan, isNotNull);
      expect(plan!.textParts, ['第一段。', '第二段。']);
      expect(plan.fullMarkdown, '第一段。\n\n第二段。');
    });

    test('single tool call with text around it: single scope', () {
      final plan = buildMessageSavePlan(
        segments: [
          TextSegment('调用前的说明。'),
          ToolCallSegment(_tc('1')),
          TextSegment('调用后的结果。'),
        ],
        fallbackText: '调用后的结果。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      // 单工具调用不属于"多步"，直接按完整输出保存
      expect(plan.fullMarkdown, '调用前的说明。\n\n调用后的结果。');
    });

    test('2 tool calls in ONE round (parallel): single scope', () {
      // 同一轮内并行调用的工具相邻出现（buildAgentChainSegments 保证），
      // 属于单步，即使前后都有文本也不弹选择面板。
      final plan = buildMessageSavePlan(
        segments: [
          TextSegment('我来查一下。'),
          ToolCallSegment(_tc('1')),
          ToolCallSegment(_tc('2')),
          TextSegment('最终回复。'),
        ],
        fallbackText: '最终回复。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      expect(plan.textParts, ['我来查一下。', '最终回复。']);
    });

    test('text only before the first tool call is not between-step feedback',
        () {
      // 多轮工具调用，但文本只出现在第一步之前：不是"步骤间反馈"。
      final plan = buildMessageSavePlan(
        segments: [
          ReasoningSegment(sectionIndex: 0),
          TextSegment('开头说明。'),
          ToolCallSegment(_tc('1')),
          ReasoningSegment(sectionIndex: 1),
          ToolCallSegment(_tc('2')),
          ReasoningSegment(sectionIndex: 2),
          TextSegment('最终回复。'),
        ],
        fallbackText: '最终回复。',
      );

      expect(plan, isNotNull);
      expect(plan!.scope, MessageSaveScope.single);
      expect(plan.fullMarkdown, '开头说明。\n\n最终回复。');
    });
  });
}
