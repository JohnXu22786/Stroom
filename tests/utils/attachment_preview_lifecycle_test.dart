import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/attachment_preview_lifecycle.dart';
import 'package:stroom/utils/attachment_preview_path.dart';

void main() {
  test(
    'failed preview writes remove partial files before rethrowing',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/partial.mp4');

      await expectLater(
        writeAttachmentPreviewFile(file.path, (file) async {
          await file.writeAsString('partial preview');
          throw StateError('simulated write failure');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await file.exists(), isFalse);
    },
  );

  test(
    'parallel previews keep separate files until each player disposes',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final firstFile = File(
        attachmentPreviewPathForPreview(
          directory.path,
          'attachment-1',
          'preview.mp4',
        ),
      );
      final secondFile = File(
        attachmentPreviewPathForPreview(
          directory.path,
          'attachment-1',
          'preview.mp4',
        ),
      );
      expect(firstFile.path, isNot(secondFile.path));
      await firstFile.writeAsString('preview');
      await secondFile.writeAsString('preview');
      final firstRelease = Completer<void>();
      final secondRelease = Completer<void>();
      final firstLifecycle = AttachmentPreviewFileLifecycle(firstFile.path);
      final secondLifecycle = AttachmentPreviewFileLifecycle(secondFile.path);

      final firstCleanup = firstLifecycle.disposePlayerAndDelete(
        () => firstRelease.future,
      );
      final repeatedCleanup = firstLifecycle.disposePlayerAndDelete(
        () async {},
      );
      final secondCleanup = secondLifecycle.disposePlayerAndDelete(
        () => secondRelease.future,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await firstFile.exists(), isTrue);
      expect(await secondFile.exists(), isTrue);

      firstRelease.complete();
      await Future.wait([firstCleanup, repeatedCleanup]);
      expect(await firstFile.exists(), isFalse);
      expect(await secondFile.exists(), isTrue);

      secondRelease.complete();
      await secondCleanup;
      expect(await secondFile.exists(), isFalse);
    },
  );
}
