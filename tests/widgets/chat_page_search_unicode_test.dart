import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_types.dart';

void main() {
  test('case-insensitive match offsets refer to original Unicode text', () {
    final text = '\u0130x';
    final matches = caseInsensitiveMatchOffsets(text, 'x');

    expect(matches, hasLength(1));
    expect(matches.single.$1, 1);
    expect(matches.single.$2, 2);
    expect(text.substring(matches.single.$1, matches.single.$2), 'x');

    final ordinaryMatches = caseInsensitiveMatchOffsets('Hi hi', 'HI');
    expect(ordinaryMatches, [(0, 2), (3, 5)]);
  });
}
