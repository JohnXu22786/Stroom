import 'message_block.dart';
import 'tool_call.dart';

List<MessageBlock> legacyToBlocks({
  required List<String> reasoningSections,
  required List<String> textChunks,
  required List<ToolCallData> toolCalls,
  required List<int> toolCallRoundStarts,
}) {
  final blocks = <MessageBlock>[];
  final numRounds = toolCallRoundStarts.isNotEmpty
      ? toolCallRoundStarts.length
      : (toolCalls.isNotEmpty ? 1 : 0);

  for (var i = 0; i < numRounds; i++) {
    // Emit EVERY reasoning section — including empty '' placeholders —
    // so blocksToSegments' ordinal sectionIndex equals the raw section
    // index in the message's reasoningSections list. Skipping empties
    // misaligned ordinals whenever a middle tool round had no reasoning
    // (interior ''), making the wrong section's text render (or none).
    // Empty blocks render nothing (ReasoningSection skips empty texts).
    if (i < reasoningSections.length) {
      blocks.add(ReasoningBlock(text: reasoningSections[i], isComplete: true));
    }
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      blocks.add(TextBlock(text: textChunks[i]));
    }
    final start = toolCallRoundStarts.isNotEmpty ? toolCallRoundStarts[i] : i;
    final end =
        i + 1 < toolCallRoundStarts.length && toolCallRoundStarts.isNotEmpty
            ? toolCallRoundStarts[i + 1]
            : toolCalls.length;
    for (var j = start; j < end && j < toolCalls.length; j++) {
      final tc = toolCalls[j];
      blocks.add(
        ToolCallBlock(
          id: tc.id,
          name: tc.name,
          arguments: tc.arguments,
          status: tc.status,
          result: tc.result,
          compactedAt: tc.compactedAt,
        ),
      );
    }
  }
  // Remaining reasoning/text after all tool rounds — interleaved, matching _buildWithRounds
  final maxRemaining = reasoningSections.length > textChunks.length
      ? reasoningSections.length
      : textChunks.length;
  for (var i = numRounds; i < maxRemaining; i++) {
    // Unconditional emission keeps ordinal section indices aligned with
    // the raw reasoningSections indices (see round loop above).
    if (i < reasoningSections.length) {
      blocks.add(ReasoningBlock(text: reasoningSections[i], isComplete: true));
    }
    if (i < textChunks.length && textChunks[i].isNotEmpty) {
      blocks.add(TextBlock(text: textChunks[i]));
    }
  }
  return blocks;
}

/// Used by message writers and the startup migration, never by the renderer.
List<MessageBlock> assistantBlocks({
  required String content,
  String? reasoningContent,
  List<String>? reasoningSections,
  List<String>? textSections,
  List<ToolCallData>? toolCalls,
  List<int>? toolCallRoundStarts,
}) {
  final blocks = legacyToBlocks(
    reasoningSections: reasoningSections?.isNotEmpty == true
        ? reasoningSections!
        : (reasoningContent?.isNotEmpty == true ? [reasoningContent!] : []),
    textChunks: textSections ?? [],
    toolCalls: toolCalls ?? [],
    toolCallRoundStarts: toolCallRoundStarts ?? [],
  );
  if (!blocks.any((block) => block is TextBlock) && content.isNotEmpty) {
    // Legacy content has no per-round boundary. Preserve the old loader's
    // trailing fallback position after any tool calls.
    blocks.add(TextBlock(text: content));
  }
  return blocks;
}
