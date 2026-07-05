import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The ID of the message currently being streamed. Survives page disposal
/// so the page can reconnect to the active stream when navigated back to.
final streamingMsgIdProvider = StateProvider<String?>((ref) => null);

/// The full accumulated reply text during streaming. Persists across page
/// lifecycle so the partial result is visible when returning to the page.
final streamingFullReplyProvider = StateProvider<String>((ref) => '');

/// Whether at least one token has been received from the AI. Used to show
/// JumpingDots (waiting) vs. streaming text on page re-entry.
final streamingHasFirstTokenProvider = StateProvider<bool>((ref) => false);

/// The reasoning content accumulated during streaming for the current
/// (most recent) reasoning section. Persists across page lifecycle so
/// the reasoning section is visible when returning to the page.
final streamingReasoningProvider = StateProvider<String>((ref) => '');

/// All reasoning sections accumulated during streaming. Each entry is a
/// completed or in-progress reasoning chain. Used to display multiple
/// reasoning buttons when there are multi-step tool call rounds.
/// The last entry is the currently active section (if streaming).
final streamingReasoningSectionsProvider =
    StateProvider<List<String>>((ref) => []);
