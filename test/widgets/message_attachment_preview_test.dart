import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/widgets/message_attachment_preview.dart';

void main() {
  group('MessageAttachmentPreview', () {
    final imageAttachment = Attachment(
      id: 'att-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileType: 'image',
      hash: 'abc123',
      storagePath: 'attachments/abc123_1234567890.jpg',
      fileSize: 102400,
    );

    final documentAttachment = Attachment(
      id: 'att-2',
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      fileType: 'document',
      hash: 'def456',
      storagePath: 'attachments/def456_1234567890.pdf',
      fileSize: 2048000,
    );

    final videoAttachment = Attachment(
      id: 'att-3',
      fileName: 'video.mp4',
      mimeType: 'video/mp4',
      fileType: 'video',
      hash: 'ghi789',
      storagePath: 'attachments/ghi789_1234567890.mp4',
      fileSize: 52428800,
    );

    final audioAttachment = Attachment(
      id: 'att-4',
      fileName: 'recording.mp3',
      mimeType: 'audio/mpeg',
      fileType: 'audio',
      hash: 'jkl012',
      storagePath: 'attachments/jkl012_1234567890.mp3',
      fileSize: 3072000,
    );

    testWidgets('renders image attachment with preview icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: imageAttachment,
            onTap: () {},
          ),
        ),
      ));

      // Should show image icon
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      // Should show filename
      expect(find.text('photo.jpg'), findsOneWidget);
      // Should wrap in GestureDetector
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders document attachment with file icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: documentAttachment,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('renders video attachment with video icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: videoAttachment,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.text('video.mp4'), findsOneWidget);
    });

    testWidgets('renders audio attachment with audio icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: audioAttachment,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      expect(find.text('recording.mp3'), findsOneWidget);
    });

    testWidgets('long filename is truncated with ellipsis', (tester) async {
      final longNameAttachment = Attachment(
        id: 'att-5',
        fileName: 'a_very_long_file_name_that_exceeds.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'mno345',
        storagePath: 'attachments/mno345_1234567890.png',
        fileSize: 51200,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: longNameAttachment,
            onTap: () {},
          ),
        ),
      ));

      // Should not show the full untruncated name
      expect(find.text('a_very_long_file_name_that_exceeds.png'), findsNothing);
      // Should show the truncated form (first 14 chars + ellipsis)
      expect(find.text('a_very_long_fi…'), findsOneWidget);
    });

    testWidgets('onTap is called when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: imageAttachment,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, true);
    });

    testWidgets('shows file size below filename', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageAttachmentPreview(
            attachment: imageAttachment,
            onTap: () {},
          ),
        ),
      ));

      // Should show formatted file size (100 KB)
      expect(find.text('100.0 KB'), findsOneWidget);
    });
  });
}
