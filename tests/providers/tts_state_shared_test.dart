import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/tts_state_shared.dart';

void main() {
  test('copyWith explicitly clears an existing error', () {
    const state = TTSState(error: 'previous synthesis failed');

    expect(state.copyWith(error: null).error, 'previous synthesis failed');
    expect(state.copyWith(clearError: true).error, isNull);
  });
}
