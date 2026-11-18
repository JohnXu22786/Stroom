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

  test(
    'failed player creation deletes the preview without disposing',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/failed.mp4');
      await file.writeAsString('preview');
      final initialization = Completer<void>()
        ..completeError(StateError('failed'));
      var playerCreated = false;
      var disposeCalled = false;

      await AttachmentPreviewFileLifecycle(file.path).disposePlayerAndDelete(
        () async => disposeCalled = true,
        shouldDisposePlayer: () => playerCreated,
        initialization: initialization.future,
      );

      expect(disposeCalled, isFalse);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'settled player errors dispose subscriptions even without a player ID',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/event-error.mp4');
      await file.writeAsString('preview');
      final initialization = Completer<void>();
      var initializationFailed = false;
      var disposeCalled = false;

      final cleanup = AttachmentPreviewFileLifecycle(file.path)
          .disposePlayerAndDelete(
            () async => disposeCalled = true,
            shouldDisposePlayer: () => initializationFailed,
            initialization: initialization.future,
          );
      await Future<void>.delayed(Duration.zero);
      expect(disposeCalled, isFalse);
      expect(await file.exists(), isTrue);

      initializationFailed = true;
      initialization.completeError(StateError('event error'));
      await cleanup;

      expect(disposeCalled, isTrue);
      expect(await file.exists(), isFalse);
    },
  );

  test(
    'created players dispose before their preview file is deleted',
    () async {
      final directory = await Directory.systemTemp.createTemp('preview-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/created.mp4');
      await file.writeAsString('preview');
      final release = Completer<void>();
      var disposeCalled = false;

      final cleanup = AttachmentPreviewFileLifecycle(file.path)
          .disposePlayerAndDelete(() {
            disposeCalled = true;
            return release.future;
          }, shouldDisposePlayer: () => true);
      await Future<void>.delayed(Duration.zero);

      expect(disposeCalled, isTrue);
      expect(await file.exists(), isTrue);
      release.complete();
      await cleanup;
      expect(await file.exists(), isFalse);
    },
  );

  test('external preview cleanup waits for the viewer grace period', () async {
    final directory = await Directory.systemTemp.createTemp('preview-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/external.pdf');
    await file.writeAsString('preview');

    final cleanup = deleteAttachmentPreviewFileAfterDelay(
      file.path,
      delay: const Duration(milliseconds: 20),
    );

    expect(await file.exists(), isTrue);
    await cleanup;
    expect(await file.exists(), isFalse);
  });
}
