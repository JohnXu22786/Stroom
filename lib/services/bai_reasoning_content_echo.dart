/// Adds b.ai's protocol-required reasoning carrier after source reasoning
/// replay has been attempted. A single ASCII space is a structural marker,
/// not model-generated reasoning.
List<Map<String, dynamic>> prepareBaiDeepSeekReasoningContentEcho({
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> originalMessages,
  required String providerId,
  String? providerPresetId,
  required String protocolId,
  required String modelId,
}) {
  if ((providerId.toLowerCase() != 'bai' && providerPresetId != 'bai') ||
      protocolId != 'openai.chat_completions' ||
      modelId.trim().toLowerCase() != 'deepseek-reasoner') {
    return messages;
  }

  var modified = false;
  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    if (message['role'] != 'assistant') {
      result.add(message);
      continue;
    }

    final original = index < originalMessages.length
        ? originalMessages[index]
        : const <String, dynamic>{};
    var prepared = message;
    if (!_hasReasoningCarrier(message['reasoning_content']) &&
        _hasReasoningCarrier(original['reasoning_content'])) {
      prepared = {
        ...message,
        'reasoning_content': original['reasoning_content'],
      };
      modified = true;
    }
    if (_hasReasoningCarrier(prepared['reasoning_content']) ||
        _hasReasoningCarrier(prepared['reasoning'])) {
      result.add(prepared);
      continue;
    }

    if (identical(prepared, message)) {
      modified = true;
      result.add({...message, 'reasoning_content': ' '});
    } else {
      result.add(prepared);
    }
  }
  return modified ? result : messages;
}

bool _hasReasoningCarrier(Object? value) {
  if (value is String) return value.trim().isNotEmpty;
  return value is List && value.isNotEmpty;
}
