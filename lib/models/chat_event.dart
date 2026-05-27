import 'tool_call.dart';

sealed class ChatEvent {}

class TextEvent extends ChatEvent {
  final String text;
  TextEvent(this.text);
}

class ToolCallStartEvent extends ChatEvent {
  final ToolCallData toolCall;
  ToolCallStartEvent(this.toolCall);
}

class ToolCallCompleteEvent extends ChatEvent {
  final String toolCallId;
  final String result;
  ToolCallCompleteEvent(this.toolCallId, this.result);
}
