import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/camera_page.dart';

void main() {
  group('CameraPage', () {
    test('can be created with default params', () {
      const page = CameraPage();
      expect(page.folder, '');
      expect(page.editAfterCapture, false);
    });

    test('can be created with custom folder', () {
      const page = CameraPage(folder: 'test_folder');
      expect(page.folder, 'test_folder');
      expect(page.editAfterCapture, false);
    });

    test('can be created with editAfterCapture true', () {
      const page = CameraPage(folder: 'f1', editAfterCapture: true);
      expect(page.folder, 'f1');
      expect(page.editAfterCapture, true);
    });
  });
}
