import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
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

    Widget buildPreview({
      required Attachment attachment,
      VoidCallback? onTap,
    }) {
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
      await tester.pumpWidget(buildPreview(
        attachment: createImageAttachment(),
        onTap: () => tapped = true,
      ));

      await tester.pump();

      await tester.tap(find.byType(MessageAttachmentPreview));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('truncates long file names', (tester) async {
      final longName = 'a' * 20 + '.png';
      final att = Attachment(
        fileName: longName,
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'ghi789',
        storagePath: '/tmp/long.png',
        fileSize: 100,
      );

      await tester.pumpWidget(buildPreview(attachment: att));
      await tester.pump();

      // Long name should be truncated (first 14 chars + …)
      expect(find.text('aaaaaaaaaaaaaa…'), findsOneWidget);
    });
  });
}
