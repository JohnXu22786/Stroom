import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/atomic_file_platform_stub.dart' as platform_stub;

void main() {
  group('AtomicFile platform stub', () {
    test('does not report Windows when FFI is unavailable', () {
      expect(platform_stub.isWindows, isFalse);
    });

    test('leaves path spelling unchanged and sensitivity unknown', () {
      const path = r'C:\CaseSensitive\tasks.json';

      expect(platform_stub.windowsOrdinalFold(path), path);
      expect(platform_stub.isCaseSensitiveDirectory(path), isNull);
    });
  });
}
