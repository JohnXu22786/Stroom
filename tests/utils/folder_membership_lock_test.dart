import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_membership_lock.dart';

void main() {
  test(
    'copies, additions, and deletions serialize membership changes',
    () async {
      final firstEntered = Completer<void>();
      final secondEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final releaseSecond = Completer<void>();
      final first = FolderMembershipLock.withCopyLock('image', 'a', () async {
        firstEntered.complete();
        await releaseFirst.future;
      });
      await firstEntered.future;
      var secondStarted = false;
      final second = FolderMembershipLock.withCopyLock(
        'image',
        'other',
        () async {
          secondStarted = true;
          secondEntered.complete();
          await releaseSecond.future;
        },
      );
      var deleted = false;
      final deletion = FolderMembershipLock.withDeleteLock(
        'image',
        'other/child',
        () async {
          deleted = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondStarted, isFalse);
      expect(deleted, isFalse);

      releaseFirst.complete();
      await secondEntered.future;
      expect(deleted, isFalse);
      releaseSecond.complete();
      await Future.wait([first, second, deletion]);
      expect(deleted, isTrue);

      final parentSnapshot = Completer<void>();
      final releaseParentCopy = Completer<void>();
      final parentCopy = FolderMembershipLock.withCopyLock(
        'video',
        'parent',
        () async {
          parentSnapshot.complete();
          await releaseParentCopy.future;
        },
      );
      await parentSnapshot.future;
      var childDeleted = false;
      final childDeletion = FolderMembershipLock.withDeleteLock(
        'video',
        'parent/child',
        () async => childDeleted = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(childDeleted, isFalse);
      releaseParentCopy.complete();
      await Future.wait([parentCopy, childDeletion]);
      expect(childDeleted, isTrue);
    },
  );

  test(
      'folder additions wait for copies but copy publication can add its destination',
      () async {
    var copiedFolderAdded = false;
    final entered = Completer<void>();
    final resume = Completer<void>();
    final copy = FolderMembershipLock.withCopyLock('text', 'source', () async {
      await FolderMembershipLock.withAddLock('text', 'target/source', () async {
        copiedFolderAdded = true;
      });
      entered.complete();
      await resume.future;
    });
    await entered.future;

    var externalFolderAdded = false;
    final add = FolderMembershipLock.withAddLock(
      'text',
      'source/empty',
      () async {
        externalFolderAdded = true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(copiedFolderAdded, isTrue);
    expect(externalFolderAdded, isFalse);

    resume.complete();
    await Future.wait([copy, add]);
    expect(externalFolderAdded, isTrue);
  });
}
