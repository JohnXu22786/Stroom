import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ID of the message currently being streamed. Survives page disposal
/// so the page can reconnect to the active stream when navigated back to.
final streamingMsgIdProvider = StateProvider<String?>((ref) => null);

/// The full accumulated reply text during streaming. Persists across page
/// lifecycle so the partial result is visible when returning to the page.
final streamingFullReplyProvider = StateProvider<String>((ref) => '');

/// Whether at least one token has been received from the AI. Used to show
/// JumpingDots (waiting) vs. streaming text on page re-entry.
final streamingHasFirstTokenProvider = StateProvider<bool>((ref) => false);

/// The reasoning content accumulated during streaming. Persists across page
/// lifecycle so reasoning section is visible when returning to the page.
final streamingReasoningProvider = StateProvider<String>((ref) => '');
