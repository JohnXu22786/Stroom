import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';

void main() {
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
