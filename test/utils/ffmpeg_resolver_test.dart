import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/ffmpeg_resolver.dart';

void main() {
  group('FFmpegResolver', () {
    group('isFFmpegAvailable', () {
      test('returns false when ffmpeg is not on system PATH', () async {
        // In test environment, there should be no ffmpeg
        final available = await FFmpegResolver.isFFmpegAvailable();
        expect(available, isFalse);
      });

      test('returns a boolean value', () async {
        final available = await FFmpegResolver.isFFmpegAvailable();
        expect(available, isA<bool>());
      });
    });

    group('resolveFFmpegPath', () {
      test('returns null when ffmpeg is not found', () async {
        final path = await FFmpegResolver.resolveFFmpegPath();
        expect(path, isNull);
      });
    });

    group('getBundledFFmpegPath', () {
      test('returns null when no bundled ffmpeg exists', () async {
        final path = await FFmpegResolver.getBundledFFmpegPath();
        expect(path, isNull);
      });
    });

    group('getPlatformSuffix', () {
      test('returns a non-empty string for the current platform', () {
        final suffix = FFmpegResolver.getPlatformSuffix();
        expect(suffix, isNotEmpty);
      });

      test('returns a string without spaces', () {
        final suffix = FFmpegResolver.getPlatformSuffix();
        expect(suffix.contains(' '), isFalse);
      });
    });

    group('getCommonInstallPaths', () {
      test('returns a list of paths', () {
        final paths = FFmpegResolver.getCommonInstallPaths();
        expect(paths, isA<List<String>>());
        // On Web (kIsWeb), the list will be empty
        // On native platforms, it should have at least one path
        // We only verify the type, not the contents
      });

      test('all paths are non-empty strings', () {
        final paths = FFmpegResolver.getCommonInstallPaths();
        for (final path in paths) {
          expect(path, isNotEmpty);
        }
      });
    });
  });
}
