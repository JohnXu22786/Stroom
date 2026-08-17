import '../chat_types.dart';

/// 消息保存的选项范围。
enum MessageSaveScope {
  /// 单份文本：无需选择，直接保存。适用于没有多步工具调用、或多步工具
  /// 调用之间没有回话反馈（只有工具和思考链）的消息。
  single,

  /// 多步工具调用且步骤之间有回话反馈：先让用户在"保存完整消息"与
  /// "保存最后的消息"之间选择。
  fullOrLast,
}

/// 用户在"保存完整消息 vs 保存最后的消息"面板中的选择。
enum MessageSaveOption { full, last }

/// 将消息的正式输出反馈（非思考链、非工具卡片）整理为可保存的 Markdown
/// 计划。
class MessageSavePlan {
  const MessageSavePlan({required this.scope, required this.textParts});

  final MessageSaveScope scope;

  /// 按出现顺序排列的正式输出反馈文本（已 trim、过滤空串）。
  final List<String> textParts;

  /// 完整消息 Markdown：每部分之间以空行（`\n\n`，标准 Markdown 换段）
  /// 隔开。
  String get fullMarkdown => textParts.join('\n\n');

  /// 最后一次正式回复的 Markdown。
  String get lastMarkdown => textParts.isEmpty ? '' : textParts.last;
}

/// 构建消息的保存计划。
///
/// [segments] 是消息的顺序段（文本 / 工具调用 / 思考链）；从中提取
/// 正式输出反馈文本。当 [segments] 中没有任何正式文本时回退到
/// [fallbackText]（消息的整体 content）。两者都没有可保存内容时返回
/// `null`。
///
/// 判定"需要用户选择"的依据：
/// - 工具调用按**连续段**分组（同一轮并行调用的相邻工具算一步，由
///   [buildAgentChainSegments] 保证同一轮的工具调用总是相邻），存在 ≥2 步
///   工具调用（多步调用）；
/// - 且在第一与最后一次工具调用**之间**出现过正式文本（步骤之间存在回话
///   反馈）；
/// - 且可保存的文本部分 ≥2（否则"完整"与"最后"没有区别）。
///
/// 满足时返回 [MessageSaveScope.fullOrLast]，否则 [MessageSaveScope.single]。
MessageSavePlan? buildMessageSavePlan({
  required List<MessageSegment> segments,
  required String fallbackText,
}) {
  final parts = <String>[];
  var firstToolCallIndex = -1;
  var lastToolCallIndex = -1;
  var toolRuns = 0;
  var inToolRun = false;

  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    if (seg is TextSegment) {
      inToolRun = false;
      final trimmed = seg.text.trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    } else if (seg is ToolCallSegment) {
      if (!inToolRun) {
        inToolRun = true;
        toolRuns++;
      }
      if (firstToolCallIndex < 0) firstToolCallIndex = i;
      lastToolCallIndex = i;
    } else {
      inToolRun = false;
    }
  }

  // 段结构中没有正式文本：回退到消息整体文本。
  if (parts.isEmpty) {
    final trimmed = fallbackText.trim();
    if (trimmed.isEmpty) return null;
    parts.add(trimmed);
  }

  final multiStep = toolRuns >= 2;
  var hasFeedbackBetweenSteps = false;
  if (multiStep && lastToolCallIndex > firstToolCallIndex) {
    for (var i = firstToolCallIndex + 1; i < lastToolCallIndex; i++) {
      final seg = segments[i];
      if (seg is TextSegment && seg.text.trim().isNotEmpty) {
        hasFeedbackBetweenSteps = true;
        break;
      }
    }
  }

  final needsChoice = multiStep && hasFeedbackBetweenSteps && parts.length >= 2;
  return MessageSavePlan(
    scope: needsChoice ? MessageSaveScope.fullOrLast : MessageSaveScope.single,
    textParts: parts,
  );
}
