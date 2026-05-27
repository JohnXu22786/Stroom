class AIStreamEvent {
  final String text;
  final bool isReasoning;
  final List<Map<String, dynamic>>? toolCalls;

  const AIStreamEvent(this.text, {this.isReasoning = false, this.toolCalls});

  bool get isToolCallEvent => toolCalls != null && toolCalls!.isNotEmpty;
}
