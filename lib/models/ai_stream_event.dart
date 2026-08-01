class AIStreamEvent {
  final String text;
  final bool isReasoning;
  final List<Map<String, dynamic>>? toolCalls;

  /// Anthropic extended thinking 的签名（signature_delta 累计结果）。
  /// 仅 Anthropic 协议产出；用于下一轮链重建时续接 thinking 块。
  final String? thinkingSignature;

  /// 本次请求的 token 计量（标准化 {inputTokens, outputTokens, cost}），
  /// 由 provider 在流末尾作为独立事件产出。
  ///
  /// 事件驱动而非共享槽（provider 实例被多对话共享，字段会被并发
  /// 覆盖）：ChatService 从事件流按请求隔离地累计。
  final Map<String, dynamic>? usage;

  const AIStreamEvent(
    this.text, {
    this.isReasoning = false,
    this.toolCalls,
    this.thinkingSignature,
    this.usage,
  });

  bool get isToolCallEvent => toolCalls != null && toolCalls!.isNotEmpty;
}
