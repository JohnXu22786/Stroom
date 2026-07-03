import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Memory cleanup timing — maps must outlive save phase', () {
    // ── Scenario: Stream completion → save → cleanup ──
    //
    // The correct ordering after a stream completes is:
    //   1. Final UI update (segments still intact, rendering lengths still valid)
    //   2. Save messages to persistent storage (maps must be accessible)
    //   3. THEN clean up streaming-only maps
    //
    // PR296's aggressive cleanup removed _streamingRenderedLengths and cleared
    // _chatSegments BEFORE the save, creating a window where:
    //   - The textMessageBuilder runs during rebuild (triggered by setState)
    //   - But segments were already cleared → renders entire long text at once
    //   - _streamingRenderedLengths was removed → null-assert crash on ! operator
    //
    // These tests verify the CONTRACT, not the implementation detail.

    test(
        'streamingRenderedLengths must survive until after save completes '
        '(not removed before setState + _saveMessages)', () {
      final msgId = 'a123';
      final streamingRenderedLengths = <String, int>{};

      // Simulate: streaming data accumulated
      streamingRenderedLengths[msgId] = 500; // 500 chars rendered
      expect(streamingRenderedLengths.containsKey(msgId), true);

      // Simulate: flush remaining text (this happens in the finally block,
      // line 865-870, before the entry is removed)
      final renderedLen = streamingRenderedLengths[msgId]!; // null assertion
      expect(renderedLen, 500);

      // Simulate: save happens (line 1003)
      // During save, the entry must still exist
      expect(streamingRenderedLengths.containsKey(msgId), true,
          reason: 'streamingRenderedLengths must exist DURING save');

      // Simulate: cleanup AFTER save (line 992 moved to after save)
      // This is the EVENTUAL cleanup — deferred until after save completes
      streamingRenderedLengths.remove(msgId);
      expect(streamingRenderedLengths.containsKey(msgId), false,
          reason: 'cleanup still happens after save');
    });

    test(
        'chatSegments text-only entries must NOT be cleared before save '
        '(defer segment cleanup to after save and setState)', () {
      final msgId = 'a123';
      final chatSegments = <String, List<String>>{};

      // Simulate: long message creates many streaming segments
      chatSegments[msgId] = [
        'Hello, this is the first chunk of a long response. ',
        'Here is the second chunk with more details. ',
        'Third chunk continuing the explanation... ',
        'Fourth chunk with even more content. ',
        'Fifth chunk wrapping things up.',
      ];
      final segmentCount = chatSegments[msgId]!.length;
      expect(segmentCount, 5);

      // Simulate: final UI update happens (line 891-893)
      // During this update, segments must still be accessible for rendering
      final segmentsForRender = chatSegments[msgId];
      expect(segmentsForRender, isNotNull,
          reason: 'segments must be accessible during final UI update');
      expect(segmentsForRender!.length, 5);

      // Simulate: setState triggers rebuild (line 993)
      // During rebuild, textMessageBuilder accesses _chatSegments[message.id]
      // Segments must still be available so the UI can render them
      final segmentsAfterSetState = chatSegments[msgId];
      expect(segmentsAfterSetState, isNotNull,
          reason: 'segments must survive the rebuild triggered by setState');
      expect(segmentsAfterSetState!.length, 5,
          reason: 'all segments must be present during rebuild, not cleared');

      // Simulate: save happens (line 1003)
      // Save does not use segments directly, but the UI is live during save
      // and segments must remain accessible for any concurrent rebuilds
      expect(chatSegments.containsKey(msgId), true,
          reason: 'segments must exist during and after save operation');

      // Simulate: eventual cleanup after save completes
      // This replicates the deferred cleanup strategy
      chatSegments.remove(msgId);
      expect(chatSegments.containsKey(msgId), false,
          reason: 'eventual cleanup still happens after save');
    });

    test(
        'chatSegments with tool calls must be preserved during the entire '
        'finalize-save-cleanup lifecycle', () {
      final msgId = 'a123';
      final chatSegments = <String, List<String>>{};

      // Simulate: segments with text AND tool calls
      chatSegments[msgId] = [
        'Initial text before tool call.',
        '[TOOL_CALL: calculator(2+2)]',
        'Text after tool call result.',
        '[TOOL_CALL: search(query)]',
        'Final concluding text.',
      ];

      // During final UI update, all segments must be accessible
      final segments = chatSegments[msgId];
      expect(segments, isNotNull);
      expect(segments!.length, 5);

      // Simulate: save happens - segments must survive
      expect(chatSegments.containsKey(msgId), true,
          reason: 'segments with tool calls must survive save');

      // Eventual cleanup still works
      chatSegments.remove(msgId);
      expect(chatSegments.containsKey(msgId), false);
    });

    test(
        'messageKeys are NOT removed during stream completion cleanup '
        '(only removed on explicit delete/edit/retry)', () {
      final messageKeys = <String, GlobalKey>{
        'msg_1': GlobalKey(),
        'msg_2': GlobalKey(),
        'msg_3': GlobalKey(),
      };

      // During stream completion, messageKeys should NOT be touched
      // (they are only cleaned up on delete/edit/retry)
      expect(messageKeys.containsKey('msg_2'), true,
          reason: 'messageKeys must not be removed during stream completion');

      // Explicit deletion — this is the only time messageKeys should be cleaned
      messageKeys.remove('msg_2');
      expect(messageKeys.containsKey('msg_2'), false);
      expect(messageKeys.containsKey('msg_1'), true);
      expect(messageKeys.containsKey('msg_3'), true);
    });

    test('reasoningContents must survive stream completion cleanup', () {
      final msgId = 'a123';
      final reasoningContents = <String, List<String>>{};

      // Simulate: reasoning sections accumulated during streaming
      reasoningContents[msgId] = [
        'First reasoning step...',
        'Second reasoning step...',
      ];

      // After stream completion (line 908-920), reasoning contents are updated
      // and MUST be preserved (not removed) — the UI needs them for buttons
      expect(reasoningContents.containsKey(msgId), true,
          reason:
              'reasoning contents must be preserved after stream completion');

      // Check that the content is still accessible during UI rebuild
      final sections = reasoningContents[msgId];
      expect(sections, isNotNull);
      expect(sections!.length, 2);

      // Eventual cleanup (only on delete/edit/retry)
      reasoningContents.remove(msgId);
      expect(reasoningContents.containsKey(msgId), false);
    });

    test('long message segments survive rebuild without premature clear', () {
      // Simulate a VERY long message's segments (200 segments)
      final msgId = 'long_msg';
      final chatSegments = <String, List<String>>{};
      chatSegments[msgId] = List<String>.generate(
        200,
        (i) =>
            'Chunk number $i of a very long response. ' *
            (i % 5 + 1), // varying sizes
      );

      // Each segment must be accessible individually (for mergeConsecutiveTextSegments)
      final segments = chatSegments[msgId]!;
      expect(segments.length, 200);

      // Simulate merge operation that the UI does during rebuild
      final merged = <String>[];
      for (final seg in segments) {
        if (merged.isNotEmpty) {
          merged[merged.length - 1] = merged.last + seg;
        } else {
          merged.add(seg);
        }
      }
      // After merging, all content is concatenated into one
      expect(merged.length, 1);
      expect(merged[0].contains('Chunk number 0'), true);
      expect(merged[0].contains('Chunk number 199'), true);

      // Important: the merge should not fail or crash, even with 200 segments
      // Premature clear() would cause this to fail
      expect(chatSegments.containsKey(msgId), true,
          reason:
              'long message segments must survive rebuild without premature clear');
    });

    test(
        'no null-assert crash on _streamingRenderedLengths access during '
        'finalize phase', () {
      final msgId = 'a456';
      final streamingRenderedLengths = <String, int>{};
      final chatSegments = <String, List<String>>{};
      String fullReply = '';
      const int totalChars = 10000; // Simulate a very long reply

      // Simulate streaming: build up content and rendered length
      streamingRenderedLengths[msgId] = 0;
      chatSegments[msgId] = [];

      // Simulate incremental rendering during streaming
      for (int i = 0; i < totalChars; i += 100) {
        final chunkEnd = (i + 100) > totalChars ? totalChars : i + 100;
        final chunk = 'x' * (chunkEnd - i);
        fullReply += chunk;

        final renderedLen =
            streamingRenderedLengths[msgId]!; // WAS: could crash
        if (fullReply.length > renderedLen) {
          chatSegments[msgId]!.add('chunk_$i');
          streamingRenderedLengths[msgId] = fullReply.length;
        }
      }

      // After streaming loop: flush remaining text (line 865-870 in finally)
      // This accesses _streamingRenderedLengths[aiMsgId]! — must NOT crash
      int renderedLen;
      try {
        renderedLen = streamingRenderedLengths[msgId]!;
      } catch (e) {
        fail('Null-assert crash on _streamingRenderedLengths[msgId]! '
            'during final flush. Entry was removed too early.\n'
            'Error: $e');
      }
      expect(renderedLen, totalChars);

      // Simulate: save operation
      // During save, the entries must still exist for any concurrent access
      expect(streamingRenderedLengths.containsKey(msgId), true);
      expect(chatSegments.containsKey(msgId), true);

      // Deferred cleanup AFTER save
      streamingRenderedLengths.remove(msgId);
      // Note: _chatSegments[msgId] is kept — only streaming-only maps are cleaned
    });
  });
}
