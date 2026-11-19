import 'tool_call.dart';

sealed class ChatEvent {
  const ChatEvent();
}

class TextEvent extends ChatEvent {
  final String text;
  final bool alreadyAccumulated;
  TextEvent(this.text, {this.alreadyAccumulated = false});
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

/// Reasoning text chunk emitted during streaming.
/// Contains a partial snippet of the model's reasoning/thinking process
/// that can be rendered incrementally in a reasoning display panel.
class ReasoningEvent extends ChatEvent {
  final String text;
  const ReasoningEvent(this.text);
}

/// A provider returned an image payload. The stream manager persists it as a
/// normal attachment before the assistant message is finalized.
class GeneratedImageEvent extends ChatEvent {
  final String base64Data;
  final String mimeType;

  const GeneratedImageEvent({required this.base64Data, required this.mimeType});
}

/// Signals that the current reasoning section has ended and a new one will
/// begin. Used by the UI to split multi-step reasoning chains into separate
/// panels when tool calls create distinct reasoning rounds.
class ReasoningSectionEndEvent extends ChatEvent {
  final void Function()? onDelivered;
  const ReasoningSectionEndEvent({this.onDelivered});
}
