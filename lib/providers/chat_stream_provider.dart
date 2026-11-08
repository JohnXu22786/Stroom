import 'package:flutter_riverpod/legacy.dart';
import '../models/tool_call.dart';

/// Appended text for the current live text section. Plain text can render from
/// these immutable deltas without materializing the accumulated section.
class StreamingTextAppend {
  final int sequence;
  final int chunkIndex;
  final String text;
  final bool hasMarkdownSyntax;

  const StreamingTextAppend({
    required this.sequence,
    required this.chunkIndex,
    required this.text,
    required this.hasMarkdownSyntax,
  });
}

/// Incremental reasoning content for the currently active section.
/// Completed section snapshots remain in [streamingReasoningSectionsProvider].
class StreamingReasoningAppend {
  final int sequence;
  final int sectionIndex;
  final String text;

  const StreamingReasoningAppend({
    required this.sequence,
    required this.sectionIndex,
    required this.text,
  });
}

final streamingTextAppendProvider =
    StateProvider.family<StreamingTextAppend?, String>(
  (ref, conversationId) => null,
);

/// The ID of the message currently being streamed. Survives page disposal
/// so the page can reconnect to the active stream when navigated back to.
final streamingMsgIdProvider =
    StateProvider.family<String?, String>((ref, convId) => null);

/// Legacy full-reply slot retained for callers that still seed stream state
/// directly. Non-empty updates are cumulative appends; callers must publish an
/// empty reset before replacing a reply. Production streaming keeps text only
/// in [streamingTextSectionsProvider] and derives the full reply when rendering.
final streamingFullReplyProvider =
    StateProvider.family<String, String>((ref, convId) => '');

/// Whether at least one token has been received from the AI. Used to show
/// JumpingDots (waiting) vs. streaming text on page re-entry.
final streamingHasFirstTokenProvider =
    StateProvider.family<bool, String>((ref, convId) => false);

/// Snapshot of the most recently completed reasoning section. Active live
/// content is delivered incrementally through [streamingReasoningAppendProvider].
final streamingReasoningProvider =
    StateProvider.family<String, String>((ref, convId) => '');

/// Throttled deltas for the active reasoning section. Consumers append these
/// to their live section state instead of receiving a copied growing prefix.
final streamingReasoningAppendProvider =
    StateProvider.family<StreamingReasoningAppend?, String>(
  (ref, convId) => null,
);

/// Snapshot of reasoning sections accumulated during streaming. Live text in
/// the active section arrives through [streamingReasoningAppendProvider]; this
/// snapshot is refreshed at section boundaries and when stream state is restored.
final streamingReasoningSectionsProvider =
    StateProvider.family<List<String>, String>((ref, convId) => []);

/// Tool call data for the currently streaming message. Each entry is a
/// [ToolCallData] with its current status (running, completed, or error).
/// Persists across page lifecycle so tool call cards are visible when
/// returning to the page.
final streamingToolCallsProvider =
    StateProvider.family<List<ToolCallData>, String>((ref, convId) => []);

/// Per-round text chunks for the currently streaming message.
/// Mirrors [ChatMessage.textSections]: each entry is the assistant's
/// speech for one tool-call round. New chunks are started at tool call
/// boundaries so the UI can interleave text between reasoning and tool
/// blocks during live streaming. The last entry is the currently growing
/// chunk.
final streamingTextSectionsProvider =
    StateProvider.family<List<String>, String>((ref, convId) => ['']);

/// Round boundary indices for tool calls during streaming.
/// Each entry is an index into [streamingToolCallsProvider] where a new
/// assistant step begins. Used by [buildAgentChainSegments] to correctly
/// group consecutive tool calls that belong to the same step.
final streamingToolCallRoundStartsProvider =
    StateProvider.family<List<int>, String>((ref, convId) => []);

/// The set of conversation IDs that currently have an active stream.
///
/// Updated by [ChatStreamManager] when a stream starts and finishes. The
/// chat page watches this to:
/// 1. Detect when a background stream completes (so it can clean up +
///    reload from DB even if the original `_startStreaming` future belongs
///    to a now-disposed page instance — e.g. user navigated away and
///    came back).
/// 2. Drive the send/stop button state per-conversation (the button shows
///    "stop" only when the current conversation is in this set).
///
/// This is decoupled from [isStreamingProvider] (a per-conversation family)
/// so that completion detection works even when the active conversation has
/// changed.
final streamingConversationsProvider =
    StateProvider<Set<String>>((ref) => <String>{});
