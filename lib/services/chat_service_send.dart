part of 'chat_service.dart';

extension ChatServiceSendExt on ChatService {
  /// Non-streaming version - collects stream into a single string.
  Future<String> send(
    String userMessage, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
  }) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(
      userMessage,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
    )) {
      chunks.add(chunk);
    }
    return chunks.join('');
  }
}
