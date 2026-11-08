import 'package:characters/characters.dart';

/// Provider requests are disabled unless the caller explicitly opts in.
bool isAsrProviderEvaluationEnabled(Map<String, String> environment) =>
    environment['ASR_EVAL_ENABLE_PROVIDER'] == 'true';

/// Requires attribution metadata before a sample can be evaluated or reported.
bool isAsrSampleProvenanceValid(Object? value) {
  if (value is! Map) return false;
  return ['source', 'license', 'attribution'].every((key) {
    final field = value[key];
    return field is String && field.trim().isNotEmpty;
  });
}

/// Selects timings from the transcript being scored, never from another run.
List<({double? start, double? end})>? asrTranscriptSegmentsForEvaluation({
  required bool providerEnabled,
  required List<({double? start, double? end})>? providerSegments,
  required List<({double? start, double? end})>? capturedTranscriptSegments,
}) =>
    providerEnabled ? providerSegments : capturedTranscriptSegments;

/// Text and timing metrics for ASR evaluations. These metrics describe only
/// the reference and transcript supplied by the caller; they do not imply
/// that either text came from a real model.
class AsrTextMetrics {
  final int characterErrors;
  final int referenceCharacters;
  final int wordErrors;
  final int referenceWords;

  const AsrTextMetrics({
    required this.characterErrors,
    required this.referenceCharacters,
    required this.wordErrors,
    required this.referenceWords,
  });

  double? get cer =>
      referenceCharacters == 0 ? null : characterErrors / referenceCharacters;

  double? get wer => referenceWords == 0 ? null : wordErrors / referenceWords;

  Map<String, Object?> toJson() => {
        'characterErrors': characterErrors,
        'referenceCharacters': referenceCharacters,
        'cer': cer,
        'wordErrors': wordErrors,
        'referenceWords': referenceWords,
        'wer': wer,
      };
}

/// Computes character error rate and whitespace-delimited word error rate.
/// CER counts Unicode grapheme clusters, so Chinese text is scored without
/// requiring a language-specific segmenter. Punctuation is retained.
AsrTextMetrics scoreAsrText(String reference, String hypothesis) {
  final referenceCharacters = reference.characters.toList();
  final hypothesisCharacters = hypothesis.characters.toList();
  final referenceWords = _words(reference);
  final hypothesisWords = _words(hypothesis);
  return AsrTextMetrics(
    characterErrors: _editDistance(referenceCharacters, hypothesisCharacters),
    referenceCharacters: referenceCharacters.length,
    wordErrors: _editDistance(referenceWords, hypothesisWords),
    referenceWords: referenceWords.length,
  );
}

List<String> _words(String text) =>
    text.trim().isEmpty ? const [] : text.trim().split(RegExp(r'\s+'));

int _editDistance(List<String> reference, List<String> hypothesis) {
  if (reference.isEmpty) return hypothesis.length;
  if (hypothesis.isEmpty) return reference.length;
  var previous = List<int>.generate(reference.length + 1, (index) => index);
  for (var row = 1; row <= hypothesis.length; row++) {
    final current = List<int>.filled(reference.length + 1, 0);
    current[0] = row;
    for (var column = 1; column <= reference.length; column++) {
      final substitution = previous[column - 1] +
          (hypothesis[row - 1] == reference[column - 1] ? 0 : 1);
      current[column] = [
        current[column - 1] + 1,
        previous[column] + 1,
        substitution,
      ].reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }
  return previous.last;
}

/// Mean absolute start/end segment boundary difference in seconds. Returns
/// null when timing is absent, incomplete, or segment counts differ.
double? meanSubtitleOffsetSeconds({
  required List<({double? start, double? end})>? reference,
  required List<({double? start, double? end})>? hypothesis,
}) {
  if (reference == null ||
      hypothesis == null ||
      reference.isEmpty ||
      reference.length != hypothesis.length) {
    return null;
  }
  var total = 0.0;
  for (var index = 0; index < reference.length; index++) {
    final expected = reference[index];
    final actual = hypothesis[index];
    if (expected.start == null ||
        expected.end == null ||
        actual.start == null ||
        actual.end == null) {
      return null;
    }
    total += (expected.start! - actual.start!).abs();
    total += (expected.end! - actual.end!).abs();
  }
  return total / (reference.length * 2);
}

/// Relative real-time factor (elapsed processing seconds / audio seconds).
double? realTimeFactor({required int elapsedMs, required double audioSeconds}) {
  if (elapsedMs < 0 || audioSeconds <= 0) return null;
  return elapsedMs / 1000 / audioSeconds;
}
