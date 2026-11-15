// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeWebDataReadForTesting = null;
    ManifestDatabase.beforeWebDataSaveForTesting = null;
  });

  tearDown(() {
    ManifestDatabase.beforeWebDataReadForTesting = null;
    ManifestDatabase.beforeWebDataSaveForTesting = null;
  });

  test(
    'concurrent cold JSON inserts preserve image, video, and text records',
    () async {
      var readCount = 0;
      ManifestDatabase.beforeWebDataReadForTesting = () async {
        readCount++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      };

      await Future.wait([
        ManifestDatabase.insertImageRecord({'id': 'image-race'}),
        ManifestDatabase.insertVideoRecord({'id': 'video-race'}),
        ManifestDatabase.insertTextRecord({'id': 'text-race'}),
      ]);

      expect(
        (await ManifestDatabase.getAllImageRecords()).map((row) => row['id']),
        ['image-race'],
      );
      expect(
        (await ManifestDatabase.getAllVideoRecords()).map((row) => row['id']),
        ['video-race'],
      );
      expect(
        (await ManifestDatabase.getAllTextRecords()).map((row) => row['id']),
        ['text-race'],
      );
      expect(
        readCount,
        1,
        reason: 'the cold manifest should be loaded once while mutations queue',
      );
    },
  );
}
