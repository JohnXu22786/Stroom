@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/tts_storage_service.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(StorageService.clearWebStorage);
  tearDown(StorageService.clearWebStorage);

  test('ttsDirExists reflects persisted Web TTS entries', () async {
    expect(await StorageService.ttsDirExists(), isFalse);

    await WebFileStore.write('unrelated/keep.wav', Uint8List.fromList([3]));
    expect(await StorageService.ttsDirExists(), isFalse);

    await StorageService.writeFile('speech.wav', Uint8List.fromList([1]));

    expect(await StorageService.ttsDirExists(), isTrue);
  });

  test(
    'clearWebStorage removes persisted storage service files only',
    () async {
      await WebFileStore.write(
        'storage_service/first.wav',
        Uint8List.fromList([1]),
      );
      await WebFileStore.write(
        'storage_service/second.wav',
        Uint8List.fromList([2]),
      );
      await WebFileStore.write('unrelated/keep.wav', Uint8List.fromList([3]));

      await StorageService.clearWebStorage();

      expect(await WebFileStore.read('storage_service/first.wav'), isNull);
      expect(await WebFileStore.read('storage_service/second.wav'), isNull);
      expect(await WebFileStore.read('unrelated/keep.wav'), [3]);
    },
  );
}
