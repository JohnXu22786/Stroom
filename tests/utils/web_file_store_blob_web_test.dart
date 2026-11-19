import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart' show idbModeReadWrite;
import 'package:idb_shim/idb_browser.dart' show idbFactoryBrowser;
import 'package:stroom/utils/web_file_store.dart';

void main() {
  test(
    'migrates attachment records to Blobs and bounds later reads',
    () async {
      const attachmentKey = 'attachments/blob-read-regression';
      const lateAttachmentKey = 'attachments/blob-read-after-migration';
      const markerKey = '__web_file_store_format__';
      const maxAttachmentBytes = 10 * 1024 * 1024;
      final payload = Uint8List(maxAttachmentBytes + 1);
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
          WebFileStore.read(
            attachmentKey,
            maxBytes: maxAttachmentBytes,
          ),
          throwsA(isA<WebFileStoreReadLimitExceededException>()),
        );
        expect(
          await WebFileStore.read(attachmentKey, maxBytes: payload.length),
          orderedEquals(payload),
        );

        // Simulate a still-open older tab writing a legacy Uint8Array after
        // startup migration has already set the format marker.
        final latePayload = Uint8List.fromList(payload.take(16).toList());
        final lateTxn = db.transaction('files', idbModeReadWrite);
        await lateTxn.objectStore('files').put(latePayload, lateAttachmentKey);
        await lateTxn.completed;
        await expectLater(
          WebFileStore.read(lateAttachmentKey, maxBytes: 8),
          throwsA(isA<WebFileStoreReadLimitExceededException>()),
        );
        expect(
          await WebFileStore.read(lateAttachmentKey,
              maxBytes: latePayload.length),
          orderedEquals(latePayload),
        );

        final readStarted = Completer<void>();
        final materialized = Completer<Uint8List?>();
        WebFileStore.readBlobOverrideForTesting = (_) {
          readStarted.complete();
          return materialized.future;
        };
        final cancelToken = CancelToken();
        final cancellableRead = WebFileStore.readCancellable(
          attachmentKey,
          cancelToken: cancelToken,
        );
        await readStarted.future;
        cancelToken.cancel('cancel during Blob materialization');
        materialized.complete(payload);
        await expectLater(
          cancellableRead,
          throwsA(same(cancelToken.cancelError)),
        );
      } finally {
        WebFileStore.readBlobOverrideForTesting = null;
        await WebFileStore.delete(attachmentKey);
        await WebFileStore.delete(lateAttachmentKey);
        db.close();
      }
    },
    skip: !kIsWeb,
  );
}
