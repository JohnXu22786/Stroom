import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_path_utils.dart';

void main() {
  group('FolderPathUtils.getFolderBaseName', () {
    test('returns the leaf segment of a path', () {
      expect(FolderPathUtils.getFolderBaseName('a/b/c'), equals('c'));
      expect(FolderPathUtils.getFolderBaseName('a'), equals('a'));
      expect(FolderPathUtils.getFolderBaseName(''), equals(''));
    });
  });

  group('FolderPathUtils.getParentFolderPath', () {
    test('returns parent path (empty = root)', () {
      expect(FolderPathUtils.getParentFolderPath('a/b/c'), equals('a/b'));
      expect(FolderPathUtils.getParentFolderPath('a'), equals(''));
      expect(FolderPathUtils.getParentFolderPath(''), equals(''));
    });
  });

  group('FolderPathUtils.getChildFolderPaths', () {
    test('root children exclude nested paths', () {
      const allPaths = {'a', 'b', 'a/x', 'c/d', 'e'};
      final children = FolderPathUtils.getChildFolderPaths('', allPaths);
      expect(children, containsAll(['a', 'b', 'e']));
      expect(children, isNot(contains('a/x')));
      expect(children, isNot(contains('c/d')));
      expect(children, hasLength(3));
    });

    test('children of a parent exclude grandchildren and the parent itself',
        () {
      const allPaths = {'a', 'a/x', 'a/x/y', 'a/z', 'b'};
      final children = FolderPathUtils.getChildFolderPaths('a', allPaths);
      expect(children, containsAll(['a/x', 'a/z']));
      expect(children, isNot(contains('a')));
      expect(children, isNot(contains('a/x/y')));
      expect(children, hasLength(2));
    });
  });

  group('FolderPathUtils.getAllDescendantFolderPaths', () {
    test('includes all nested descendants, excludes self', () {
      const allPaths = {'a', 'a/x', 'a/x/y', 'b', 'ab'};
      final descendants =
          FolderPathUtils.getAllDescendantFolderPaths('a', allPaths);
      expect(descendants, containsAll(['a/x', 'a/x/y']));
      expect(descendants, isNot(contains('a')));
      expect(descendants, isNot(contains('b')));
      expect(descendants, isNot(contains('ab')),
          reason: 'prefix match must respect the / boundary');
    });

    test('root descendants are all non-top-level paths', () {
      const allPaths = {'a', 'a/x', 'b/c/d', 'top'};
      final descendants =
          FolderPathUtils.getAllDescendantFolderPaths('', allPaths);
      expect(descendants, containsAll(['a/x', 'b/c/d']));
      expect(descendants, isNot(contains('a')));
      expect(descendants, isNot(contains('top')));
    });
  });

  group('FolderPathUtils.validateFolderName', () {
    test('rejects empty, overlong and slash-containing names', () {
      expect(FolderPathUtils.validateFolderName(''), isNotNull);
      expect(FolderPathUtils.validateFolderName('   '), isNotNull);
      expect(FolderPathUtils.validateFolderName('x' * 101), isNotNull);
      expect(FolderPathUtils.validateFolderName('a/b'), isNotNull);
    });

    test('accepts valid names', () {
      expect(FolderPathUtils.validateFolderName('folder'), isNull);
      expect(FolderPathUtils.validateFolderName('文件夹 2024'), isNull);
      expect(FolderPathUtils.validateFolderName('x' * 100), isNull);
    });
  });
}
