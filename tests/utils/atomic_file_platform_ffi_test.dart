import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/atomic_file_platform_ffi.dart' as platform_ffi;

void main() {
  group('AtomicFile FFI platform adapter', () {
    test('reports whether this runtime is Windows', () {
      expect(platform_ffi.isWindows, Platform.isWindows);
    });

    test('keeps case-sensitivity unknown without Windows APIs',
        skip: Platform.isWindows, () {
      expect(platform_ffi.isCaseSensitiveDirectory(Directory.systemTemp.path),
          isNull);
    });

    test('queries case sensitivity for an existing Windows directory', () {
      expect(
        platform_ffi.isCaseSensitiveDirectory(Directory.systemTemp.path),
        isNotNull,
      );
    }, skip: !Platform.isWindows);

    test('folds Windows path letters using ordinal uppercase', () {
      expect(platform_ffi.windowsOrdinalFold(r'C:\tasksσ.json'),
          r'C:\TASKSΣ.JSON');
    }, skip: !Platform.isWindows);
  });
}
