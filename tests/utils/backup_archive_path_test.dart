// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/backup_archive_path.dart';

void main() {
  test('rejects Windows console device names in archive path segments', () {
    for (final path in [
      r'CONIN$',
      r'CONOUT$',
      r'nested/CONIN$',
      r'nested/CONOUT$',
      r'cOnIn$',
      r'cOnOuT$',
      r'CONIN$.txt',
      r'CONOUT$.json',
      r'nested/cOnIn$.txt',
      r'nested/cOnOuT$.json',
    ]) {
      expect(
        isSafeBackupArchivePathForTesting(path, isWindows: true),
        isFalse,
        reason: '$path must not be a safe Windows archive path',
      );
    }
  });

  test(
    'allows ordinary similar names and keeps non-Windows paths unchanged',
    () {
      for (final path in [
        'console-input',
        'console-output.txt',
        'CONINPUT',
        'nested/console-input.json',
      ]) {
        expect(
          isSafeBackupArchivePathForTesting(path, isWindows: true),
          isTrue,
          reason: '$path is an ordinary name',
        );
      }

      expect(
        isSafeBackupArchivePathForTesting(r'CONIN$', isWindows: false),
        isTrue,
        reason: 'reserved Windows device names remain valid off Windows',
      );
    },
  );
}
