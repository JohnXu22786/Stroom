// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';

void main() {
  tearDown(AttachmentStorage.resetOverridesForTesting);

  group('MessageAttachmentPreview', () {
    Attachment createImageAttachment() {
      return Attachment(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'abc123',
        storagePath: '/tmp/test.png',
        fileSize: 1024,
      );
    }

    Widget buildPreview({required Attachment attachment, VoidCallback? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: attachment,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('onTap is called when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildPreview(
          attachment: createImageAttachment(),
          onTap: () => tapped = true,
        ),
      );

      await tester.pump();

      await tester.tap(find.byType(MessageAttachmentPreview));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('reloads the thumbnail when its storage path changes', (
      tester,
    ) async {
      final firstImage = Uint8List.fromList([1, 2, 3]);
      final secondImage = Uint8List.fromList([4, 5, 6]);
      final secondImageLoaded = Completer<Uint8List?>();
      final readPaths = <String>[];
      AttachmentStorage.readFileOverrideForTesting = (path) {
        readPaths.add(path);
        return switch (path) {
          '/tmp/first.png' => Future.value(firstImage),
          '/tmp/second.png' => secondImageLoaded.future,
          _ => Future.value(null),
        };
      };

      Attachment attachmentAt(String storagePath, String fileName) =>
          Attachment(
            fileName: fileName,
            mimeType: 'image/png',
            fileType: 'image',
            hash: 'abc123',
            storagePath: storagePath,
            fileSize: 1024,
          );

      Widget buildPreview(Attachment attachment) => MaterialApp(
            home: Scaffold(
              body: MessageAttachmentPreview(
                attachment: attachment,
                onTap: () {},
              ),
            ),
          );

      await tester.pumpWidget(
        buildPreview(attachmentAt('/tmp/first.png', 'first.png')),
      );
      await tester.pump();
      await tester.pump();

      expect(readPaths, ['/tmp/first.png']);
      expect(find.byType(ExtendedImage), findsOneWidget);

      await tester.pumpWidget(
        buildPreview(attachmentAt('/tmp/second.png', 'second.png')),
      );
      await tester.pump();

      expect(readPaths, ['/tmp/first.png', '/tmp/second.png']);
      expect(find.byType(ExtendedImage), findsNothing);

      secondImageLoaded.complete(secondImage);
      await tester.pump();
      await tester.pump();

      final displayedImage = tester.widget<ExtendedImage>(
        find.byType(ExtendedImage),
      );
      expect(displayedImage.image, ExtendedImage.memory(secondImage).image);

      await tester.pumpWidget(
        buildPreview(attachmentAt('/tmp/second.png', 'renamed.png')),
      );
      await tester.pump();
      expect(readPaths, ['/tmp/first.png', '/tmp/second.png']);
    });

    testWidgets('keeps fitting file names unchanged', (tester) async {
      final att = Attachment(
        fileName: 'notes.txt',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'ghi789',
        storagePath: '/tmp/long.png',
        fileSize: 100,
      );

      await tester.pumpWidget(buildPreview(attachment: att));
      await tester.pump();

      final label = tester.widget<ConstrainedText>(
        find.byType(ConstrainedText).first,
      );
      expect(label.data, 'notes.txt');
    });

    testWidgets('bounds the complete long file name for overflow display', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longName = 'a-very-long-attachment-name.png';
      final att = Attachment(
        fileName: longName,
        mimeType: 'image/png',
        fileType: 'document',
        hash: 'ghi789',
        storagePath: '/tmp/long.png',
        fileSize: 100,
      );

      await tester.pumpWidget(buildPreview(attachment: att));
      await tester.pump();

      final label = tester.widget<ConstrainedText>(
        find.byType(ConstrainedText).first,
      );
      expect(label.data, longName);
      expect(tester.getSize(find.byType(ConstrainedText).first).width, 80);
      expect(tester.takeException(), isNull);
    });
  });
}
