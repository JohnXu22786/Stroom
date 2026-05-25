import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  group('MediaResource width/height', () {
    test('creates resource with width and height', () {
      final res = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'video',
        ext: 'mp4',
        width: 1920,
        height: 1080,
      );
      expect(res.width, 1920);
      expect(res.height, 1080);
    });

    test('serializes and deserializes width/height', () {
      final res = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'video',
        ext: 'mp4',
        width: 1280,
        height: 720,
      );
      final map = res.toMap();
      expect(map['width'], 1280);
      expect(map['height'], 720);

      final restored = MediaResource.fromMap(map);
      expect(restored.width, 1280);
      expect(restored.height, 720);
    });

    test('width/height default to null', () {
      final res = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'video',
        ext: 'mp4',
      );
      expect(res.width, isNull);
      expect(res.height, isNull);
    });

    test('copyWith updates width/height', () {
      final res = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final updated = res.copyWith(width: 640, height: 480);
      expect(updated.width, 640);
      expect(updated.height, 480);
      expect(res.width, isNull); // original unchanged
    });

    test('backward compatible deserialization without width/height', () {
      final map = {
        'url': 'https://example.com/v.mp4',
        'name': 'video',
        'ext': 'mp4',
      };
      final res = MediaResource.fromMap(map);
      expect(res.width, isNull);
      expect(res.height, isNull);
    });
  });

  group('video probe result fields', () {
    test('isPlayable determines probe eligibility', () {
      final playable = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        isPlayable: true,
      );
      expect(playable.isPlayable, isTrue);

      final notPlayable = MediaResource(
        url: 'https://example.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        isPlayable: false,
      );
      expect(notPlayable.isPlayable, isFalse);
    });
  });
}
