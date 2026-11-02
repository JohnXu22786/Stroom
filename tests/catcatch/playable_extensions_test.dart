import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/sniffing_engine.dart';

void main() {
  test('Opus and WebA URLs are playable without a MIME type', () {
    for (final extension in ['opus', 'weba']) {
      expect(
        SniffingEngine.isPlayable(extension, null),
        isTrue,
        reason: 'URL candidates with .$extension have no response MIME type',
      );
    }
  });
}
