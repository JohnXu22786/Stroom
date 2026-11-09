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
}
