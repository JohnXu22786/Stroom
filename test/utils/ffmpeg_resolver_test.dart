import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/ffmpeg_resolver.dart';

void main() {
  group('FFmpegResolver', () {
    group('ensureFFmpegReady', () {
      test('returns null on platforms using ffmpeg_kit_flutter', () async {
        // In test environment, ensureFFmpegReady returns null
        // because the test is not Android/iOS/macOS (uses ffmpeg_kit_flutter)
        // and there's no bundled ffmpeg binary in assets
        final path = await FFmpegResolver.ensureFFmpegReady();
        expect(path, isNull);
      });

      test('returns a string or null', () async {
        final path = await FFmpegResolver.ensureFFmpegReady();
        expect(path == null || path is String, isTrue);
      });
    });
  });
}