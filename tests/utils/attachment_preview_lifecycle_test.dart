import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/attachment_preview_lifecycle.dart';

void main() {
  test(
    'preview cleanup waits for the first in-flight player disposal',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/preview.mp4');
      await file.writeAsString('preview');
      final releasePlayer = Completer<void>();
      final lifecycle = AttachmentPreviewFileLifecycle(file.path);

      final cleanup = lifecycle.disposePlayerAndDelete(
        () => releasePlayer.future,
      );
      final repeatedCleanup = lifecycle.disposePlayerAndDelete(() async {});
      await Future<void>.delayed(Duration.zero);
      expect(await file.exists(), isTrue);

      releasePlayer.complete();
      await Future.wait([cleanup, repeatedCleanup]);
      expect(await file.exists(), isFalse);
    },
  );
}
