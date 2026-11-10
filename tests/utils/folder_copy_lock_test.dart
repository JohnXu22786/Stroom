import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/folder_copy_lock.dart';

void main() {
  test(
    'same destination waits and releases queued copies after failure',
    () async {
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final first = FolderCopyLock.withLock('image', 'target/folder', () async {
        firstEntered.complete();
        await releaseFirst.future;
        throw StateError('copy failed');
      });
      final firstResult = expectLater(first, throwsStateError);
      await firstEntered.future;

      var secondStarted = false;
      final second = FolderCopyLock.withLock(
        'image',
        'target/folder',
        () async {
          secondStarted = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondStarted, isFalse);

      releaseFirst.complete();
      await firstResult;
      await second;
      expect(secondStarted, isTrue);
    },
  );

  test('different destination and provider keys do not wait', () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    final first = FolderCopyLock.withLock('image', 'target/folder', () async {
      firstEntered.complete();
      await releaseFirst.future;
    });
    await firstEntered.future;

    var otherDestinationStarted = false;
    await FolderCopyLock.withLock('image', 'target/other', () async {
      otherDestinationStarted = true;
    });
    var otherProviderStarted = false;
    await FolderCopyLock.withLock('text', 'target/folder', () async {
      otherProviderStarted = true;
    });
    expect(otherDestinationStarted, isTrue);
    expect(otherProviderStarted, isTrue);

    releaseFirst.complete();
    await first;
  });
}
