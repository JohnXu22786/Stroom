import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/asr_evaluation.dart';

void main() {
  test('provider requests require the explicit environment opt-in', () {
    expect(isAsrProviderEvaluationEnabled({}), isFalse);
    expect(
      isAsrProviderEvaluationEnabled({'ASR_EVAL_ENABLE_PROVIDER': '1'}),
      isFalse,
    );
    expect(
      isAsrProviderEvaluationEnabled({'ASR_EVAL_ENABLE_PROVIDER': 'true'}),
      isTrue,
    );
  });

  test('requires complete source, license, and attribution provenance', () {
    expect(
      isAsrSampleProvenanceValid({
        'source': 'dataset archive 2026-01',
        'license': 'CC-BY-4.0',
        'attribution': 'Dataset author',
      }),
      isTrue,
    );
    expect(
      isAsrSampleProvenanceValid({
        'source': 'dataset archive 2026-01',
        'license': 'CC-BY-4.0',
      }),
      isFalse,
    );
    expect(isAsrSampleProvenanceValid(null), isFalse);
  });

  test('subtitle offsets use timings from the transcript being scored', () {
    final capturedSegments = [(start: 0.0, end: 1.0)];

    expect(
      asrTranscriptSegmentsForEvaluation(
        providerEnabled: true,
        providerSegments: null,
        capturedTranscriptSegments: capturedSegments,
      ),
      isNull,
    );
    expect(
      asrTranscriptSegmentsForEvaluation(
        providerEnabled: false,
        providerSegments: [(start: 0.2, end: 0.8)],
        capturedTranscriptSegments: capturedSegments,
      ),
      same(capturedSegments),
    );
  });

  group('scoreAsrText', () {
    test('scores Chinese characters as graphemes without a tokenizer', () {
      final result = scoreAsrText('你好世界', '你好世間');

      expect(result.characterErrors, 1);
      expect(result.referenceCharacters, 4);
      expect(result.cer, 0.25);
      expect(result.wordErrors, 1);
      expect(result.wer, 1);
    });

    test('scores mixed-language names, punctuation, and number edits', () {
      final result = scoreAsrText('Alice 在 2026 年到达。', 'Alicia 在 2025 年到达!');

      expect(result.characterErrors, 4);
      expect(result.referenceCharacters, 17);
      expect(result.wordErrors, 3);
      expect(result.referenceWords, 4);
    });

    test('scores insertions, deletions, and empty references', () {
      expect(scoreAsrText('one two', 'one two extra').wordErrors, 1);
      expect(scoreAsrText('one two', 'two').wordErrors, 1);
      expect(scoreAsrText('', '').cer, isNull);
      expect(scoreAsrText('', 'noise').characterErrors, 5);
    });
  });

  test('reports mean absolute subtitle boundary offset', () {
    final offset = meanSubtitleOffsetSeconds(
      reference: [(start: 0.0, end: 1.0), (start: 2.0, end: 3.0)],
      hypothesis: [(start: 0.2, end: 0.8), (start: 2.1, end: 3.1)],
    );

    expect(offset, closeTo(0.15, 0.0001));
    expect(
      meanSubtitleOffsetSeconds(
        reference: [(start: 0, end: 1)],
        hypothesis: null,
      ),
      isNull,
    );
  });

  test('computes RTF and declines invalid audio duration', () {
    expect(realTimeFactor(elapsedMs: 500, audioSeconds: 2), 0.25);
    expect(realTimeFactor(elapsedMs: 500, audioSeconds: 0), isNull);
  });
}
