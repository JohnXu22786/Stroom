import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/xxhash64.dart';

void main() {
  test('matches canonical xxHash64 vectors', () {
    expect(xxHash64(const <int>[]).toRadixString(16), 'ef46db3751d8e999');
    expect(xxHash64(utf8.encode('a')).toRadixString(16), 'd24ec4f1a98c6e5b');
    expect(xxHash64(const <int>[], seed: BigInt.one).toRadixString(16),
        'd5afba1336a3be4b');
  });
}
