part of 'chat_types_test.dart';

void chatTypesGroup2() {
  group('buildAgentChainSegments', () {
    ToolCallData _tc(String id, String name) => ToolCallData(
          id: id,
          name: name,
          arguments: {},
          status: ToolCallStatus.completed,
        );

    test('empty inputs returns empty list', () {
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: [],
        toolCalls: [],
      );
      expect(segments, isEmpty);
    });

    test('single reasoning section + text + tool call', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1'],
        textChunks: ['text1'],
        toolCalls: [_tc('1', 'web_search')],
      );
      expect(segments.length, 3);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'web_search');
    });

    test('two round Agent chain: R1 T1 TC1 R2 T2 TC2', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2'],
        textChunks: ['text1', 'text2'],
        toolCalls: [_tc('1', 'search1'), _tc('2', 'search2')],
      );
      expect(segments.length, 6);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'search1');
      expect(segments[3], isA<ReasoningSegment>());
      expect((segments[3] as ReasoningSegment).sectionIndex, 1);
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'text2');
      expect(segments[5], isA<ToolCallSegment>());
      expect((segments[5] as ToolCallSegment).data.name, 'search2');
    });

    test('final round has text but no tool call', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2'],
        textChunks: ['text1', 'text2'],
        toolCalls: [_tc('1', 'search1')],
      );
      expect(segments.length, 5);
      expect(segments[0], isA<ReasoningSegment>());
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect(segments[3], isA<ReasoningSegment>());
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'text2');
    });

    test('extra tool calls without reasoning are interleaved', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1'],
        textChunks: ['text1', 'text2'],
        toolCalls: [_tc('1', 's1'), _tc('2', 's2')],
      );
      expect(segments.length, 5);
      expect(segments[0], isA<ReasoningSegment>());
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 's1');
      expect(segments[3], isA<TextSegment>());
      expect((segments[3] as TextSegment).text, 'text2');
      expect(segments[4], isA<ToolCallSegment>());
      expect((segments[4] as ToolCallSegment).data.name, 's2');
    });

    test('text and tool calls without reasoning: T1 TC1 T2', () {
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['before search', 'after search'],
        toolCalls: [_tc('1', 'web_search')],
      );
      expect(segments.length, 3);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).text, 'before search');
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'web_search');
      expect(segments[2], isA<TextSegment>());
      expect((segments[2] as TextSegment).text, 'after search');
    });

    test('text and tool calls without reasoning: 2 rounds', () {
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['t1', 't2', 't3'],
        toolCalls: [_tc('1', 'tc1'), _tc('2', 'tc2')],
      );
      expect(segments.length, 5);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).text, 't1');
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'tc1');
      expect(segments[2], isA<TextSegment>());
      expect((segments[2] as TextSegment).text, 't2');
      expect(segments[3], isA<ToolCallSegment>());
      expect((segments[3] as ToolCallSegment).data.name, 'tc2');
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 't3');
    });

    test('empty reasoning sections are skipped', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['', 'real thinking'],
        textChunks: ['orphan text', 'visible text'],
        toolCalls: [],
      );
      expect(segments.length, 3);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).text, 'orphan text');
      expect(segments[1], isA<ReasoningSegment>());
      expect((segments[1] as ReasoningSegment).sectionIndex, 1);
      expect(segments[2], isA<TextSegment>());
      expect((segments[2] as TextSegment).text, 'visible text');
    });

    test('isLastReasoningStreaming marks last section', () {
      final segments = buildAgentChainSegments(
        reasoningSections: ['r1', 'r2'],
        textChunks: [],
        toolCalls: [],
        isLastReasoningStreaming: true,
      );
      expect((segments[0] as ReasoningSegment).isStreaming, false);
      expect((segments[1] as ReasoningSegment).isStreaming, true);
    });

    test('only text, no reasoning, no tool calls', () {
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['simple text'],
        toolCalls: [],
      );
      expect(segments.length, 1);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).text, 'simple text');
    });

    test('trailing empty reasoning does not lose trailing text chunk', () {
      // Simulates a 3-round Agent chain where the final ReasoningSectionEndEvent
      // adds an empty section, and the final answer is in textChunks[2].
      // Regression test for Bug 1: empty reasoning skipping text/tool calls.
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2', 'think3', ''],
        textChunks: ['text1', 'text2', 'final answer'],
        toolCalls: [_tc('1', 'tc1'), _tc('2', 'tc2')],
      );
      // R0 T0 TC0 R1 T1 TC1 R2 T2 (+R3 empty skipped but T2 still shows)
      // 7 segments: R, T, TC, R, T, TC, R, T
      expect(segments.length, 8);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect(segments[3], isA<ReasoningSegment>());
      expect((segments[3] as ReasoningSegment).sectionIndex, 1);
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'text2');
      expect(segments[5], isA<ToolCallSegment>());
      expect(segments[6], isA<ReasoningSegment>());
      expect((segments[6] as ReasoningSegment).sectionIndex, 2);
      expect(segments[7], isA<TextSegment>());
      expect((segments[7] as TextSegment).text, 'final answer');
    });

    test('multiple tool calls in one round are grouped together', () {
      // Manager output: text "step1" → TC(A), TC(B), TC(C) → text "step2"
      // All 3 tools in one round (only the first TC creates a new chunk).
      final segments = buildAgentChainSegments(
        reasoningSections: ['think'],
        textChunks: ['step1', 'step2'],
        toolCalls: [_tc('1', 'A'), _tc('2', 'B'), _tc('3', 'C')],
        toolCallRoundStarts: [0],
      );
      // R0, T0(step1), TC0(A), TC1(B), TC2(C), T1(step2)
      expect(segments.length, 6);
      expect(segments[0], isA<ReasoningSegment>());
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'step1');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'A');
      expect(segments[3], isA<ToolCallSegment>());
      expect((segments[3] as ToolCallSegment).data.name, 'B');
      expect(segments[4], isA<ToolCallSegment>());
      expect((segments[4] as ToolCallSegment).data.name, 'C');
      expect(segments[5], isA<TextSegment>());
      expect((segments[5] as TextSegment).text, 'step2');
    });

    test('two rounds each with multiple tool calls are interleaved correctly',
        () {
      // Manager output: think1, text1 → TC(A1), TC(B1) → response1 →
      //   TC(A2), TC(C2), TC(D2) → response2
      // Round 0 starts at TC(0), round 1 starts at TC(2).
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2'],
        textChunks: ['text1', 'response1', 'response2'],
        toolCalls: [
          _tc('1', 'A1'),
          _tc('2', 'B1'),
          _tc('3', 'A2'),
          _tc('4', 'C2'),
          _tc('5', 'D2'),
        ],
        toolCallRoundStarts: [0, 2],
      );
      // R0, T0(text1), TC0(A1), TC1(B1),
      // R1(think2), T1(response1), TC2(A2), TC3(C2), TC4(D2), T2(response2)
      expect(segments.length, 10);

      // Round 0
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'A1');
      expect(segments[3], isA<ToolCallSegment>());
      expect((segments[3] as ToolCallSegment).data.name, 'B1');

      // Round 1
      expect(segments[4], isA<ReasoningSegment>());
      expect((segments[4] as ReasoningSegment).sectionIndex, 1);
      expect(segments[5], isA<TextSegment>());
      expect((segments[5] as TextSegment).text, 'response1');
      expect(segments[6], isA<ToolCallSegment>());
      expect((segments[6] as ToolCallSegment).data.name, 'A2');
      expect(segments[7], isA<ToolCallSegment>());
      expect((segments[7] as ToolCallSegment).data.name, 'C2');
      expect(segments[8], isA<ToolCallSegment>());
      expect((segments[8] as ToolCallSegment).data.name, 'D2');
      expect(segments[9], isA<TextSegment>());
      expect((segments[9] as TextSegment).text, 'response2');
    });

    test('tool calls adjacent without text between them all grouped', () {
      // Manager output: text "before" → TC(X), TC(Y), TC(Z) → text "after"
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['before', 'after'],
        toolCalls: [_tc('1', 'X'), _tc('2', 'Y'), _tc('3', 'Z')],
        toolCallRoundStarts: [0],
      );
      // T0(before), TC0(X), TC1(Y), TC2(Z), T1(after)
      expect(segments.length, 5);
      expect(segments[0], isA<TextSegment>());
      expect((segments[0] as TextSegment).text, 'before');
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'X');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'Y');
      expect(segments[3], isA<ToolCallSegment>());
      expect((segments[3] as ToolCallSegment).data.name, 'Z');
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'after');
    });

    test('multiple tool calls with no text or reasoning at all', () {
      // Manager output: TC(A), TC(B), TC(C) with no text events.
      // textChunks = ['', ''] (initial + first TC created new chunk).
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['', ''],
        toolCalls: [_tc('1', 'A'), _tc('2', 'B'), _tc('3', 'C')],
        toolCallRoundStarts: [0],
      );
      expect(segments.length, 3);
      expect(segments[0], isA<ToolCallSegment>());
      expect((segments[0] as ToolCallSegment).data.name, 'A');
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'B');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'C');
    });

    test('legacy algorithm without toolCallRoundStarts still works', () {
      // Historical data: no round boundary info → uses 1:1 pairing.
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2'],
        textChunks: ['text1', 'text2'],
        toolCalls: [_tc('1', 'tc1'), _tc('2', 'tc2')],
      );
      expect(segments.length, 6);
      expect(segments[0], isA<ReasoningSegment>());
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ToolCallSegment>());
      expect(segments[3], isA<ReasoningSegment>());
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'text2');
      expect(segments[5], isA<ToolCallSegment>());
    });

    // ── Edge cases for re-entry / persisted data alignment ──

    test('round 0 with empty leading text: tools still grouped correctly', () {
      // Manager scenario: TC(A), TC(B) immediately (no text before),
      // then text "result". textChunks = ['', 'result'], roundStarts = [0].
      // The leading '' is round 0's empty text.
      final segments = buildAgentChainSegments(
        reasoningSections: [],
        textChunks: ['', 'result'],
        toolCalls: [_tc('1', 'A'), _tc('2', 'B')],
        toolCallRoundStarts: [0],
      );
      // Round 0: T('') skipped, TC(A), TC(B). Trailing: T('result').
      expect(segments.length, 3);
      expect(segments[0], isA<ToolCallSegment>());
      expect((segments[0] as ToolCallSegment).data.name, 'A');
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'B');
      expect(segments[2], isA<TextSegment>());
      expect((segments[2] as TextSegment).text, 'result');
    });

    test('persisted data with empty entries: indices align to rounds', () {
      // After reload from DB (with roundStarts preserved), textSections
      // may include empty entries (e.g. ['', 'text2', 'final']).
      // _buildWithRounds must skip empties but preserve index alignment.
      final segments = buildAgentChainSegments(
        reasoningSections: ['r1', '', 'r3'],
        textChunks: ['', 'text2', 'final'],
        toolCalls: [
          _tc('1', 'A'),
          _tc('2', 'B'),
          _tc('3', 'C'),
          _tc('4', 'D'),
        ],
        toolCallRoundStarts: [0, 2],
      );
      // Round 0: R('r1'), T('') skip, TC(A), TC(B)
      // Round 1: R('') skip, T('text2'), TC(C), TC(D)
      // Trailing (i=2): R('r3'), T('final')
      expect(segments.length, 8);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'A');
      expect(segments[2], isA<ToolCallSegment>());
      expect((segments[2] as ToolCallSegment).data.name, 'B');
      expect(segments[3], isA<TextSegment>());
      expect((segments[3] as TextSegment).text, 'text2');
      expect(segments[4], isA<ToolCallSegment>());
      expect((segments[4] as ToolCallSegment).data.name, 'C');
      expect(segments[5], isA<ToolCallSegment>());
      expect((segments[5] as ToolCallSegment).data.name, 'D');
      expect(segments[6], isA<ReasoningSegment>());
      expect((segments[6] as ReasoningSegment).sectionIndex, 2);
      expect(segments[7], isA<TextSegment>());
      expect((segments[7] as TextSegment).text, 'final');
    });

    test('no tool calls: roundStarts empty uses legacy and works', () {
      // During early streaming (reasoning + text, no tools yet),
      // roundStarts = [] → falls to legacy algorithm.
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2'],
        textChunks: ['text1', 'text2'],
        toolCalls: [],
        toolCallRoundStarts: [],
      );
      // Legacy: 2 rounds, each R + T.
      expect(segments.length, 4);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<TextSegment>());
      expect((segments[1] as TextSegment).text, 'text1');
      expect(segments[2], isA<ReasoningSegment>());
      expect((segments[2] as ReasoningSegment).sectionIndex, 1);
      expect(segments[3], isA<TextSegment>());
      expect((segments[3] as TextSegment).text, 'text2');
    });

    test('reasoning-only round 2 renders interleaved, not at the bottom', () {
      // Real post-stream data for a 2-round flow where each round is
      // reasoning + tool call with NO visible text:
      //   reasoningSections = ['think1', 'think2', ''] (trailing placeholder
      //     from the final ReasoningSectionEndEvent)
      //   textChunks = ['', '', 'final answer'] (round 1/2 text empty)
      //   toolCalls = [A, B], roundStarts = [0, 1]
      // Regression guard for the "all thoughts at the bottom" bug: with the
      // correct round boundary (roundStarts=[0,1]), think2 must appear
      // between tool A and tool B — NOT after all tools.
      final segments = buildAgentChainSegments(
        reasoningSections: ['think1', 'think2', ''],
        textChunks: ['', '', 'final answer'],
        toolCalls: [_tc('1', 'A'), _tc('2', 'B')],
        toolCallRoundStarts: [0, 1],
      );
      // R0, TC(A), R1, TC(B), T(final answer)
      expect(segments.length, 5);
      expect(segments[0], isA<ReasoningSegment>());
      expect((segments[0] as ReasoningSegment).sectionIndex, 0);
      expect(segments[1], isA<ToolCallSegment>());
      expect((segments[1] as ToolCallSegment).data.name, 'A');
      expect(segments[2], isA<ReasoningSegment>());
      expect((segments[2] as ReasoningSegment).sectionIndex, 1,
          reason: 'think2 must be interleaved after tool A. If it is at the '
              'end of the segment list, the round-boundary bug regressed.');
      expect(segments[3], isA<ToolCallSegment>());
      expect((segments[3] as ToolCallSegment).data.name, 'B');
      expect(segments[4], isA<TextSegment>());
      expect((segments[4] as TextSegment).text, 'final answer');
    });
  });
}
