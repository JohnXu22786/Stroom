import 'package:flutter_riverpod/legacy.dart';
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

/// Shared state provider tracking whether AI is currently streaming a response.
final isStreamingProvider = StateProvider<bool>((ref) => false);

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

/// Shared state provider tracking which tool names are enabled by the user.
/// Applies to both built-in and MCP tools uniformly.
final enabledToolNamesProvider = StateProvider<Set<String>>((ref) => {});
