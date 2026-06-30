import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/widgets/file_preview.dart';

void main() {
  group('FilePreviewChip', () {
    final testAttachment = Attachment(
      id: 'att-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileType: 'image',
      hash: 'abc123',
      storagePath: 'attachments/abc123_1234567890.jpg',
      fileSize: 102400,
    );

    testWidgets('renders file icon and name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
          ),
        ),
      ));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('photo.jpg'), findsOneWidget);
    });

    testWidgets('onTap is called when chip is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
          ),
        ),
      ));

      // Tap the GestureDetector wrapping the chip
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, true);
    });

    testWidgets('works without onTap (no crash)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
          ),
        ),
      ));

      // Should render without crashing
      expect(find.byType(FilePreviewChip), findsOneWidget);
    });

    testWidgets('onTap and onRemove both work independently', (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
            onRemove: () => removed = true,
          ),
        ),
      ));

      // Tap the main chip area (GestureDetector)
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, true);
      expect(removed, false);
    });

    testWidgets('tapping remove button fires onRemove, NOT onTap',
        (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
            onRemove: () => removed = true,
          ),
        ),
      ));

      // Tap the close (remove) icon which is inside the inner GestureDetector
      await tester.tap(find.byIcon(Icons.close));
      expect(removed, true);
      // The inner GestureDetector should absorb the tap, preventing onTap from firing
      expect(tapped, false);
    });

    testWidgets('long filename is truncated with ellipsis', (tester) async {
      final longNameAttachment = Attachment(
        id: 'att-long',
        fileName: 'a_very_long_file_name_that_exceeds.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'mno345',
        storagePath: 'attachments/mno345_1234567890.png',
        fileSize: 51200,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(attachment: longNameAttachment),
        ),
      ));

      // Should not show the full untruncated name
      expect(find.text('a_very_long_file_name_that_exceeds.png'), findsNothing);
      // Should show the truncated form (first 14 chars + ellipsis)
      expect(find.text('a_very_long_fi…'), findsOneWidget);
    });

    testWidgets('different file types show correct icons', (tester) async {
      final types = <String, IconData>{
        'image': Icons.image_outlined,
        'audio': Icons.audiotrack_outlined,
        'video': Icons.videocam_outlined,
        'document': Icons.insert_drive_file_outlined,
      };

      for (final entry in types.entries) {
        final att = Attachment(
          id: 'att-${entry.key}',
          fileName: 'file.${entry.key}',
          mimeType: '${entry.key}/test',
          fileType: entry.key,
          hash: 'hash-${entry.key}',
          storagePath: 'attachments/hash-${entry.key}.test',
          fileSize: 1024,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: FilePreviewChip(attachment: att),
          ),
        ));

        expect(find.byIcon(entry.value), findsOneWidget,
            reason: 'Expected ${entry.value} for fileType ${entry.key}');
      }
    });
  });
}
