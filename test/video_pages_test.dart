import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/video_capture_page.dart';
import 'package:stroom/pages/video_gallery_page.dart';

void main() {
  group('VideoCapturePage', () {
    test('can be created with default folder', () {
      const page = VideoCapturePage();
      expect(page.folder, '');
    });

    test('can be created with custom folder', () {
      const page = VideoCapturePage(folder: 'test_folder');
      expect(page.folder, 'test_folder');
    });
  });

  group('VideoGalleryPage', () {
    test('can be created', () {
      const page = VideoGalleryPage();
      expect(page, isNotNull);
    });
  });
}
