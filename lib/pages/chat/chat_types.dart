import 'package:flutter_riverpod/legacy.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart';

/// Segments that make up an AI message, rendered in order.
/// Each segment is either text content, a tool call card,
/// or a reasoning section marker.
sealed class MessageSegment {}

class TextSegment extends MessageSegment {
  final String text;
  TextSegment(this.text);
}

class ToolCallSegment extends MessageSegment {
  final ToolCallData data;
  ToolCallSegment(this.data);
}

/// A reasoning section segment that displays a "思考完成/思考中" button
/// inline in the message flow. Each instance corresponds to one reasoning
/// section at the position where it occurred in the event stream.
///
/// [sectionIndex] refers to the index in the message's reasoning sections
/// list (_reasoningContents[messageId]). The actual reasoning text is stored
/// in that map and updated live during streaming. This segment acts as a
/// positional marker for rendering the reasoning button at the correct
/// place relative to text and tool call segments.
class ReasoningSegment extends MessageSegment {
  final int sectionIndex;
  final bool isStreaming;

  ReasoningSegment({
    required this.sectionIndex,
    this.isStreaming = false,
  });
}

/// Metadata for a search match within a message.
class SearchMatch {
  final String messageId;
  final int matchStart;
  final int matchEnd;

  SearchMatch(this.messageId, this.matchStart, this.matchEnd);
}

/// Search mode: within current conversation or across all conversations.
enum SearchMode { current, global }

/// Merges consecutive [TextSegment] entries in a [MessageSegment] list into
/// a single [TextSegment] with concatenated text.
///
/// This avoids visual breaks between arbitrary streaming chunk boundaries
/// when rendering segments. For example, during streaming, text chunks like
/// ["你好", "世界", "!"] that were split by throttle timing are merged into
/// a single ["你好世界!"] text block, so they render in one MarkdownWidget.
///
/// Segments of different types (e.g. [ToolCallSegment]) act as natural
/// boundaries and are never merged with adjacent [TextSegment]s.
List<MessageSegment> mergeConsecutiveTextSegments(
    List<MessageSegment> segments) {
  if (segments.isEmpty) return [];
  final merged = <MessageSegment>[];
  for (final seg in segments) {
    if (seg is TextSegment && merged.isNotEmpty && merged.last is TextSegment) {
      final last = merged.last as TextSegment;
      merged[merged.length - 1] = TextSegment(last.text + seg.text);
    } else {
      merged.add(seg);
    }
  }
  return merged;
}

/// Builds an interleaved list of [MessageSegment]s representing an Agent
/// chain. Each round i consists of:
///   Reasoning[i] → Text[i] → ToolCall[i]
///
/// Empty reasoning sections are skipped but their corresponding text chunks
/// and tool calls are still emitted at the right position.
///
/// [reasoningSections] — may contain empty strings (filtered out).
/// [textChunks] — per-round text; chunks[i] is text before toolCalls[i].
/// [toolCalls] — tool call data for each round.
/// [isLastReasoningStreaming] — marks the last ReasoningSegment as streaming.
List<MessageSegment> buildAgentChainSegments({
  required List<String> reasoningSections,
  required List<String> textChunks,
  required List<ToolCallData> toolCalls,
  bool isLastReasoningStreaming = false,
  List<int>? toolCallRoundStarts,
}) {
  // When round boundaries are known (from live streaming), use the
  // round-based algorithm that correctly groups consecutive tool calls.
  // When not known (historical data), fall back to the legacy 1:1 pairing.
  if (toolCallRoundStarts != null && toolCallRoundStarts.isNotEmpty) {
    return _buildWithRounds(
      reasoningSections,
      textChunks,
      toolCalls,
      isLastReasoningStreaming,
      toolCallRoundStarts,
    );
  }
  return _buildLegacy(
    reasoningSections,
    textChunks,
    toolCalls,
    isLastReasoningStreaming,
  );
}

/// Round-based interleaving for live streaming data.
///
/// Uses [roundStarts] — indices into [toolCalls] where each assistant
/// "step" begins — to group consecutive tool calls that belong to the
/// same round (e.g. multiple tools called simultaneously).
/// Index of the last non-empty reasoning section. Differs from
/// `sections.length - 1` when a placeholder empty string was appended
/// for the next round (see _buildWithRounds / _buildLegacy).
int _lastNonEmptyIndex(List<String> sections) {
  for (int j = sections.length - 1; j >= 0; j--) {
    if (sections[j].isNotEmpty) return j;
  }
  return -1;
}

List<MessageSegment> _buildWithRounds(
  List<String> reasoningSections,
  List<String> textChunks,
  List<ToolCallData> toolCalls,
  bool isLastReasoningStreaming,
  List<int> roundStarts,
) {
  final segments = <MessageSegment>[];
  final numRounds = roundStarts.length;

  for (int i = 0; i < numRounds; i++) {
    // Reasoning for this round
    if (i < reasoningSections.length && reasoningSections[i].isNotEmpty) {
      segments.add(ReasoningSegment(
        sectionIndex: i,
        isStreaming: isLastReasoningStreaming &&
            i == _lastNonEmptyIndex(reasoningSections),
      ));
    }

    // Text before this round's tool calls
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      segments.add(TextSegment(textChunks[i]));
    }

    // All tool calls in this round (grouped together)
    final start = roundStarts[i];
    final end = i + 1 < numRounds ? roundStarts[i + 1] : toolCalls.length;
    for (int j = start; j < end && j < toolCalls.length; j++) {
      segments.add(ToolCallSegment(toolCalls[j]));
    }
  }

  // Remaining reasoning and text after all tool rounds
  for (int i = numRounds;
      i < reasoningSections.length || i < textChunks.length;
      i++) {
    if (i < reasoningSections.length && reasoningSections[i].isNotEmpty) {
      segments.add(ReasoningSegment(
        sectionIndex: i,
        isStreaming: isLastReasoningStreaming &&
            i == _lastNonEmptyIndex(reasoningSections),
      ));
    }
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      segments.add(TextSegment(textChunks[i]));
    }
  }

  return segments;
}

/// Legacy 1:1 interleaving for historical data (no round boundary info).
///
/// Each tool call is placed at the same round index as its corresponding
/// reasoning section and text chunk. When multiple tool calls exist per
/// round, they may appear in the wrong visual position — this is the
/// known limitation that [toolCallRoundStarts] resolves.
List<MessageSegment> _buildLegacy(
  List<String> reasoningSections,
  List<String> textChunks,
  List<ToolCallData> toolCalls,
  bool isLastReasoningStreaming,
) {
  final segments = <MessageSegment>[];
  final maxRounds = [
    reasoningSections.length,
    textChunks.length,
    toolCalls.length,
  ].fold(0, (a, b) => a > b ? a : b);

  for (var i = 0; i < maxRounds; i++) {
    if (i < reasoningSections.length && reasoningSections[i].isNotEmpty) {
      segments.add(ReasoningSegment(
        sectionIndex: i,
        isStreaming: isLastReasoningStreaming &&
            i == _lastNonEmptyIndex(reasoningSections),
      ));
    }

    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      segments.add(TextSegment(textChunks[i]));
    }

    if (i < toolCalls.length) {
      segments.add(ToolCallSegment(toolCalls[i]));
    }
  }

  return segments;
}

/// Shared state provider tracking whether AI is currently streaming a response
/// for a specific conversation.
final isStreamingProvider =
    StateProvider.family<bool, String>((ref, conversationId) => false);

/// Shared state provider tracking whether reasoning is enabled.
final reasoningEnabledProvider = StateProvider<bool>((ref) => false);

/// Shared state provider tracking whether the reasoning effort toggle is enabled.
final reasoningEffortEnabledProvider = StateProvider<bool>((ref) => false);

/// Shared state provider tracking reasoning effort level ('low', 'medium', 'high').
final reasoningEffortProvider = StateProvider<String>((ref) => 'medium');

/// Shared state provider tracking selected values for each reasoning parameter.
/// Key is the paramName (e.g. 'reasoning_effort', 'thinking.type'),
/// value is the selected option string (e.g. 'high', 'enabled').
final reasoningParamValuesProvider =
    StateProvider<Map<String, String>>((ref) => {});

// ── Block converters ─────────────────────────────────────────────────

List<MessageSegment> blocksToSegments(List<MessageBlock> blocks) {
  final segs = <MessageSegment>[];
  for (final b in blocks) {
    switch (b) {
      case TextBlock(:final text):
        segs.add(TextSegment(text));
      case ReasoningBlock(:final isComplete):
        segs.add(ReasoningSegment(
          sectionIndex: segs.whereType<ReasoningSegment>().length,
          isStreaming: !isComplete,
        ));
      case ToolCallBlock(
          :final id,
          :final name,
          :final arguments,
          :final status,
          :final result,
          :final compactedAt
        ):
        segs.add(ToolCallSegment(ToolCallData(
          id: id,
          name: name,
          arguments: arguments,
          status: status,
          result: result,
          compactedAt: compactedAt,
        )));
      case ErrorBlock(:final message):
        segs.add(TextSegment('[Error: $message]'));
    }
  }
  return segs;
}

List<MessageBlock> legacyToBlocks({
  required List<String> reasoningSections,
  required List<String> textChunks,
  required List<ToolCallData> toolCalls,
  required List<int> toolCallRoundStarts,
}) {
  final blocks = <MessageBlock>[];
  final numRounds = toolCallRoundStarts.isNotEmpty
      ? toolCallRoundStarts.length
      : (toolCalls.isNotEmpty ? 1 : 0);

  for (var i = 0; i < numRounds; i++) {
    // Emit EVERY reasoning section — including empty '' placeholders —
    // so blocksToSegments' ordinal sectionIndex equals the raw section
    // index in the message's reasoningSections list. Skipping empties
    // misaligned ordinals whenever a middle tool round had no reasoning
    // (interior ''), making the wrong section's text render (or none).
    // Empty blocks render nothing (ReasoningSection skips empty texts).
    if (i < reasoningSections.length) {
      blocks.add(ReasoningBlock(text: reasoningSections[i], isComplete: true));
    }
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      blocks.add(TextBlock(text: textChunks[i]));
    }
    final start = toolCallRoundStarts.isNotEmpty ? toolCallRoundStarts[i] : i;
    final end =
        i + 1 < toolCallRoundStarts.length && toolCallRoundStarts.isNotEmpty
            ? toolCallRoundStarts[i + 1]
            : toolCalls.length;
    for (var j = start; j < end && j < toolCalls.length; j++) {
      final tc = toolCalls[j];
      blocks.add(ToolCallBlock(
        id: tc.id,
        name: tc.name,
        arguments: tc.arguments,
        status: tc.status,
        result: tc.result,
        compactedAt: tc.compactedAt,
      ));
    }
  }
  // Remaining reasoning/text after all tool rounds — interleaved, matching _buildWithRounds
  final maxRemaining = reasoningSections.length > textChunks.length
      ? reasoningSections.length
      : textChunks.length;
  for (var i = numRounds; i < maxRemaining; i++) {
    // Unconditional emission keeps ordinal section indices aligned with
    // the raw reasoningSections indices (see round loop above).
    if (i < reasoningSections.length) {
      blocks.add(ReasoningBlock(text: reasoningSections[i], isComplete: true));
    }
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      blocks.add(TextBlock(text: textChunks[i]));
    }
  }
  return blocks;
}

/// Shared state provider tracking which tool names are enabled by the user.
/// Applies to both built-in and MCP tools uniformly.
final enabledToolNamesProvider = StateProvider<Set<String>>((ref) => {});

// ============================================================================
// 上下文统计显示格式化（opencode sidebar 风格）
// ============================================================================

/// 格式化 token 数为可读文本（1.2K / 12.3K / 1.2M）。
String formatTokenCount(int tokens) {
  if (tokens < 1000) return '$tokens';
  if (tokens < 1000000) {
    final k = tokens / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}K';
  }
  final m = tokens / 1000000;
  return '${m.toStringAsFixed(m >= 10 ? 1 : 2)}M';
}

/// 格式化花费（美元）：<0.01 显示 4 位小数，否则 2 位。
String formatCost(double cost) {
  if (cost <= 0) return '0.00';
  if (cost < 0.01) return cost.toStringAsFixed(4);
  return cost.toStringAsFixed(2);
}
