import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_stream_manager.dart';

/// App-level singleton provider for [ChatStreamManager]. The manager owns
/// the [ChatAdapter] and manages the streaming lifecycle independently of
/// any page widget. It persists across navigation changes so that API
/// calls continue in the background when the user leaves the chat page.
final chatStreamManagerProvider = Provider<ChatStreamManager>((ref) {
  return ChatStreamManager(ref);
});
