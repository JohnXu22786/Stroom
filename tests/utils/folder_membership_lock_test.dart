import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_membership_lock.dart';

Future<void> _waitForSignalOrOperationFailure(
  Completer<void> signal,
  Future<void> operation,
  String description,
) {
  final operationFinished = operation.then<void>((_) {
    if (!signal.isCompleted) {
      throw StateError('$description completed before reaching its barrier');
    }
  });
  return Future.any([signal.future, operationFinished]);
}

Future<void> _drainOperations(Iterable<Future<void>> operations) async {
  try {
    await Future.wait(operations);
  } catch (_) {
    // The originating assertion or barrier wait reports the test failure.
  }
}

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
      Future<void>? second;
      Future<void>? deletion;
      try {
        await _waitForSignalOrOperationFailure(
          firstEntered,
          first,
          'first copy',
        );
        var secondStarted = false;
        second = FolderMembershipLock.withCopyLock(
          'image',
          'other',
          () async {
            secondStarted = true;
            secondEntered.complete();
            await releaseSecond.future;
          },
        );
        var deleted = false;
        deletion = FolderMembershipLock.withDeleteLock(
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
        await _waitForSignalOrOperationFailure(
          secondEntered,
          second,
          'second copy',
        );
        expect(deleted, isFalse);
        releaseSecond.complete();
        await Future.wait([first, second, deletion]);
        expect(deleted, isTrue);
      } finally {
        if (!releaseFirst.isCompleted) releaseFirst.complete();
        if (!releaseSecond.isCompleted) releaseSecond.complete();
        await _drainOperations([
          first,
          if (second != null) second,
          if (deletion != null) deletion,
        ]);
      }

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
      Future<void>? childDeletion;
      try {
        await _waitForSignalOrOperationFailure(
          parentSnapshot,
          parentCopy,
          'parent copy',
        );
        var childDeleted = false;
        childDeletion = FolderMembershipLock.withDeleteLock(
          'video',
          'parent/child',
          () async => childDeleted = true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(childDeleted, isFalse);
        releaseParentCopy.complete();
        await Future.wait([parentCopy, childDeletion]);
        expect(childDeleted, isTrue);
      } finally {
        if (!releaseParentCopy.isCompleted) releaseParentCopy.complete();
        await _drainOperations([
          parentCopy,
          if (childDeletion != null) childDeletion,
        ]);
      }
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
    Future<void>? add;
    try {
      await _waitForSignalOrOperationFailure(
        entered,
        copy,
        'copy callback',
      );

      var externalFolderAdded = false;
      add = FolderMembershipLock.withAddLock(
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
    } finally {
      if (!resume.isCompleted) resume.complete();
      await _drainOperations([copy, if (add != null) add]);
    }
  });
}
