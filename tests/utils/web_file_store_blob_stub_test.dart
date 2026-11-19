import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/web_file_store_blob_stub.dart' as blob_store;

void main() {
  test('non-web blob storage stub preserves byte storage behavior', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);

    expect(blob_store.isBlob(bytes), isFalse);
    expect(blob_store.blobByteLength(bytes), isNull);
    expect(blob_store.createBlob(bytes), same(bytes));
    expect(await blob_store.readBlob(bytes), isNull);
  });
}
