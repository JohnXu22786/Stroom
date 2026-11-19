import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:stroom/utils/web_file_store.dart';

void main() {
  test(
    'rejects an oversized Blob by size before reading its payload',
    () async {
      final blob = web.Blob([Uint8List(1024 * 1024).toJS].toJS);

      await expectLater(
        // ignore: invalid_use_of_visible_for_testing_member
        WebFileStore.readStoredValueForTesting(blob, maxBytes: 32),
        throwsA(isA<WebFileStoreReadLimitExceededException>()),
      );
    },
  );
}
