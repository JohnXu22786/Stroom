import 'package:flutter_riverpod/legacy.dart';
import '../models/tool_call.dart';

/// The ID of the message currently being streamed. Survives page disposal
/// so the page can reconnect to the active stream when navigated back to.
final streamingMsgIdProvider =
    StateProvider.family<String?, String>((ref, convId) => null);

/// The full accumulated reply text during streaming. Persists across page
/// lifecycle so the partial result is visible when returning to the page.
final streamingFullReplyProvider =
    StateProvider.family<String, String>((ref, convId) => '');

/// Whether at least one token has been received from the AI. Used to show
/// JumpingDots (waiting) vs. streaming text on page re-entry.
final streamingHasFirstTokenProvider =
    StateProvider.family<bool, String>((ref, convId) => false);

/// The reasoning content accumulated during streaming for the current
/// (most recent) reasoning section. Persists across page lifecycle so
/// the reasoning section is visible when returning to the page.
final streamingReasoningProvider =
    StateProvider.family<String, String>((ref, convId) => '');

/// All reasoning sections accumulated during streaming. Each entry is a
/// completed or in-progress reasoning chain. Used to display multiple
/// reasoning buttons when there are multi-step tool call rounds.
/// The last entry is the currently active section (if streaming).
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
