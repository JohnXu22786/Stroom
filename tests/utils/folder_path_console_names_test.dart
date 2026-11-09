import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_path_utils.dart';

void main() {
  group('Windows console device name validation', () {
    const reservedNames = [r'CONIN$', r'CONOUT$'];

    test('file validator rejects names, extensions, and case variants', () {
      for (final name in reservedNames) {
        expect(FolderPathUtils.validateFileName(name), isNotNull);
        expect(
          FolderPathUtils.validateFileName('${name.toLowerCase()}.txt'),
          isNotNull,
        );
      }
      expect(FolderPathUtils.validateFileName('console-output.txt'), isNull);
    });

    test('folder validator rejects names, extensions, and case variants', () {
      for (final name in reservedNames) {
        expect(FolderPathUtils.validateFolderName(name), isNotNull);
        expect(
          FolderPathUtils.validateFolderName('${name.toLowerCase()}.txt'),
          isNotNull,
        );
      }
      expect(FolderPathUtils.validateFolderName('console-input'), isNull);
    });
  });
}
