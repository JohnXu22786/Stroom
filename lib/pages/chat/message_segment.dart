import '../../models/tool_call.dart';

/// A sealed class representing one segment of an assistant message.
/// A message can be split into multiple interleaved text and tool-call segments.
sealed class MessageSegment {}

/// A text-only segment within a chat message.
class TextSegment extends MessageSegment {
  final String text;
  TextSegment(this.text);
}

/// A tool-call segment within a chat message.
class ToolCallSegment extends MessageSegment {
  final ToolCallData data;
  ToolCallSegment(this.data);
}

/// Represents one match found by the chat search feature.
class SearchMatch {
  final String messageId;
  final int matchStart;
  final int matchEnd;
  SearchMatch(this.messageId, this.matchStart, this.matchEnd);
}
