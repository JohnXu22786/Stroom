class AIStreamEvent {
  final String text;
  final bool isReasoning;
  final List<Map<String, dynamic>>? toolCalls;

  /// Anthropic extended thinking 的签名（signature_delta 累计结果）。
  /// 仅 Anthropic 协议产出；用于下一轮链重建时续接 thinking 块。
  final String? thinkingSignature;

  const AIStreamEvent(
    this.text, {
    this.isReasoning = false,
    this.toolCalls,
    this.thinkingSignature,
  });

  bool get isToolCallEvent => toolCalls != null && toolCalls!.isNotEmpty;
}
