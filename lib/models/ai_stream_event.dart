class AIStreamEvent {
  final String text;
  final bool isReasoning;
  final List<Map<String, dynamic>>? toolCalls;

  /// Anthropic extended thinking 的签名（signature_delta 累计结果）。
  /// 仅 Anthropic 协议产出；用于下一轮链重建时续接 thinking 块。
  final String? thinkingSignature;

  /// 本次请求的 token 计量（标准化 {inputTokens, outputTokens, cost}），
  /// 由 provider 作为独立事件产出；可在一条流中多次更新。
  ///
  /// 事件驱动而非共享槽（provider 实例被多对话共享，字段会被并发
  /// 覆盖）：ChatService 从事件流按请求隔离地累计。若 usage 在一条流中
  /// 多次更新，事件携带累计快照；[usageCostIncrement] 是本次新增的成本。
  final Map<String, dynamic>? usage;

  /// 当流在完成前被取消时，已收到的 usage 也必须可计入。多次 usage
  /// 快照若携带累计 cost，此字段避免每次更新都重复累加。
  final double? usageCostIncrement;

  const AIStreamEvent(
    this.text, {
    this.isReasoning = false,
    this.toolCalls,
    this.thinkingSignature,
    this.usage,
    this.usageCostIncrement,
  });

  bool get isToolCallEvent => toolCalls != null && toolCalls!.isNotEmpty;
}
