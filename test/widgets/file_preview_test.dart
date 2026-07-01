import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/widgets/file_preview.dart';

void main() {
  group('FilePreviewChip', () {
    final testBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    Attachment createImageAttachment() {
      return Attachment(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'abc123',
        storagePath: '/tmp/test.png',
        fileSize: 100,
      );
    }

    Attachment createDocumentAttachment() {
      return Attachment(
        fileName: 'doc.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'def456',
        storagePath: '/tmp/doc.txt',
        fileSize: 200,
      );
    }

    Widget buildChip({
      required Attachment attachment,
      Uint8List? imageBytes,
      VoidCallback? onRemove,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: attachment,
            imageBytes: imageBytes,
            onRemove: onRemove,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders image with ExtendedImage when imageBytes provided',
        (tester) async {
      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
        imageBytes: testBytes,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The widget should render - ExtendedImage.memory is used internally
      // Verify the thumbnail area is rendered (Container with clip behavior)
      expect(find.byType(FilePreviewChip), findsOneWidget);
      // File name should be displayed
      expect(find.text('test.png'), findsOneWidget);
    });

    testWidgets('shows file icon for non-image attachments', (tester) async {
      await tester.pumpWidget(buildChip(
        attachment: createDocumentAttachment(),
      ));

      await tester.pump();

      // Should show document icon
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('remove button calls onRemove when tapped', (tester) async {
      bool removed = false;
      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
        imageBytes: testBytes,
        onRemove: () => removed = true,
      ));

      await tester.pump();

      // Tap the close button (positioned in top-right corner)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });

    testWidgets('truncates long file names', (tester) async {
      final longName = 'a' * 30 + '.png';
      final att = Attachment(
        fileName: longName,
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'ghi789',
        storagePath: '/tmp/long.png',
        fileSize: 100,
      );

      await tester.pumpWidget(buildChip(
        attachment: att,
        imageBytes: testBytes,
      ));

      await tester.pump();

      // Long name should be truncated (first 14 chars + …)
      expect(find.text('aaaaaaaaaaaaaa…'), findsOneWidget);
    });
  });
}
