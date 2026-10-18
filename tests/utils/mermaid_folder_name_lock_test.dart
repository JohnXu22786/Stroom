import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/mermaid_folder_name_lock.dart';

void main() {
  test(
    'serializes one folder, allows another folder, and releases after failure',
    () async {
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final order = <String>[];

      final first = MermaidFolderNameLock.withLock('charts', () async {
        order.add('first');
        firstEntered.complete();
        await releaseFirst.future;
        throw StateError('simulated save failure');
      });
      await firstEntered.future;

      final second = MermaidFolderNameLock.withLock('charts', () async {
        order.add('second');
      });
      final otherFolder = MermaidFolderNameLock.withLock('other', () async {
        order.add('other');
      });

      await otherFolder;
      await Future<void>.delayed(Duration.zero);
      expect(order, ['first', 'other']);

      releaseFirst.complete();
      await expectLater(first, throwsStateError);
      await second;
      expect(order, ['first', 'other', 'second']);
    },
  );
}
