import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';

void main() {
  group('isAudioPreviewResource', () {
    test('classifies supported audio formats and preserves video/ogg', () {
      const audioOga = MediaResource(
        url: 'https://example.com/audio.oga',
        name: 'audio',
        ext: 'oga',
      );
      const audioOggMime = MediaResource(
        url: 'https://example.com/audio.ogg',
        name: 'audio',
        ext: 'ogg',
        mimeType: 'audio/ogg',
      );
      const audioWma = MediaResource(
        url: 'https://example.com/audio.wma',
        name: 'audio',
        ext: 'wma',
      );
      const videoOgg = MediaResource(
        url: 'https://example.com/video.ogg',
        name: 'video',
        ext: 'ogg',
        mimeType: 'video/ogg',
      );

      expect(isAudioPreviewResource(audioOga), isTrue);
      expect(isAudioPreviewResource(audioOggMime), isTrue);
      expect(isAudioPreviewResource(audioWma), isTrue);
      expect(isAudioPreviewResource(videoOgg), isFalse);
    });
  });
}
