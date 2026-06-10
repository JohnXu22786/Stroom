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

/// Shared state provider tracking whether AI is currently streaming a response.
final isStreamingProvider = StateProvider<bool>((ref) => false);
