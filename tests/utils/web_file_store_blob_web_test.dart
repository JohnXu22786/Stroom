import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart' show idbModeReadWrite;
import 'package:idb_shim/idb_browser.dart' show idbFactoryBrowser;
import 'package:stroom/utils/web_file_store.dart';

void main() {
  test('migrates attachment records to Blobs and bounds later reads', () async {
    const attachmentKey = 'attachments/blob-read-regression';
    const markerKey = '__web_file_store_format__';
    final payload = Uint8List(1024 * 1024);
    for (var i = 0; i < payload.length; i++) {
      payload[i] = i % 251;
    }

    final db = await idbFactoryBrowser.open(
      'stroom_file_store',
      version: 1,
      onUpgradeNeeded: (event) {
        event.transaction.database.createObjectStore('files');
      },
    );
    final seedTxn = db.transaction('files', idbModeReadWrite);
    final store = seedTxn.objectStore('files');
    await store.put(payload, attachmentKey);
    await store.delete(markerKey);
    await seedTxn.completed;

    try {
      expect(await WebFileStore.migrateAttachmentValuesToBlobs(), isTrue);
      await expectLater(
        WebFileStore.read(attachmentKey, maxBytes: 32),
        throwsA(isA<WebFileStoreReadLimitExceededException>()),
      );
      expect(
        await WebFileStore.read(attachmentKey, maxBytes: payload.length),
        orderedEquals(payload),
      );
    } finally {
      await WebFileStore.delete(attachmentKey);
      db.close();
    }
  });
}
