import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/content_hash_save_lock.dart';

void main() {
  test('same-hash saves serialize while nested acquisition is reentrant',
      () async {
    final locks = ContentHashSaveLock();
    final entries = <int>[];
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();

    final first = locks.withLock('shared-hash', () async {
      entries.add(1);
      firstEntered.complete();
      await releaseFirst.future;
      await locks.withLock('shared-hash', () async {
        entries.add(2);
      });
    });
    await firstEntered.future;

    final second = locks.withLock('shared-hash', () async {
      entries.add(3);
    });
    await Future<void>.delayed(Duration.zero);
    expect(entries, [1]);

    releaseFirst.complete();
    await Future.wait([first, second]);

    expect(entries, [1, 2, 3]);
  });

  test('folder readers coexist and a parent deletion waits for descendants',
      () async {
    final locks = ContentHashSaveLock();
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondEntered = Completer<void>();
    final releaseSecond = Completer<void>();
    final deletionEntered = Completer<void>();

    final first = locks.withFolderReadLocks(
      ['folder:Trips'],
      () async {
        firstEntered.complete();
        await releaseFirst.future;
      },
    );
    await firstEntered.future;
    final second = locks.withFolderReadLocks(
      ['folder:Trips'],
      () async {
        secondEntered.complete();
        await releaseSecond.future;
      },
    );
    try {
      await secondEntered.future.timeout(const Duration(seconds: 5));
      final deletion = locks.withFolderWriteLock('folder:Trips', () async {
        deletionEntered.complete();
      });
      await Future<void>.delayed(Duration.zero);
      expect(deletionEntered.isCompleted, isFalse);
      releaseFirst.complete();
      releaseSecond.complete();
      await Future.wait([first, second]);
      await deletion;
    } finally {
      if (!releaseFirst.isCompleted) releaseFirst.complete();
      if (!releaseSecond.isCompleted) releaseSecond.complete();
    }
    expect(deletionEntered.isCompleted, isTrue);
  });
}
