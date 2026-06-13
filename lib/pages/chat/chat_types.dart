import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/models/tool_call.dart';

/// Segments that make up an AI message, rendered in order.
/// Each segment is either text content or a tool call card.
sealed class MessageSegment {}

class TextSegment extends MessageSegment {
  final String text;
  TextSegment(this.text);
}

class ToolCallSegment extends MessageSegment {
  final ToolCallData data;
  ToolCallSegment(this.data);
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
List<MessageSegment> mergeConsecutiveTextSegments(List<MessageSegment> segments) {
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

/// Shared state provider tracking reasoning effort level ('low', 'medium', 'high').
final reasoningEffortProvider = StateProvider<String>((ref) => 'medium');

/// Shared state provider tracking which tool names are enabled by the user.
/// Applies to both built-in and MCP tools uniformly.
final enabledToolNamesProvider = StateProvider<Set<String>>((ref) => {});
