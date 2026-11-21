import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';

void main() {
  test('new LLM provider effort defaults keep the requested order', () {
    final params = defaultLlmProviderReasoningParams();

    expect(params, hasLength(1));
    expect(params.single.paramName, 'reasoning_effort');
    expect(params.single.isEffortParam, isTrue);
    expect(params.single.options, [
      'none',
      'minimal',
      'low',
      'medium',
      'high',
      'xhigh',
      'max',
    ]);
    expect(
      ReasoningParam.fromMap(params.single.toMap()).options,
      params.single.options,
    );
  });
}
