import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';

void main() {
  group('PreviewChip', () {
    final testBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    Widget buildChip({
      required String fileName,
      required Uint8List bytes,
      required bool isImage,
      VoidCallback? onRemove,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PreviewChip(
            fileName: fileName,
            bytes: bytes,
            isImage: isImage,
            onRemove: onRemove ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders image chip with ExtendedImage when isImage is true',
        (tester) async {
      await tester.pumpWidget(buildChip(
        fileName: 'photo.png',
        bytes: testBytes,
        isImage: true,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Widget renders without crash
      expect(find.byType(PreviewChip), findsOneWidget);
    });

    testWidgets('renders file chip for non-image', (tester) async {
      await tester.pumpWidget(buildChip(
        fileName: 'document.pdf',
        bytes: testBytes,
        isImage: false,
      ));

      await tester.pump();

      expect(find.byType(PreviewChip), findsOneWidget);
      expect(find.text('document.pdf'), findsOneWidget);
    });

    testWidgets('remove button triggers onRemove callback', (tester) async {
      bool removed = false;
      await tester.pumpWidget(buildChip(
        fileName: 'photo.png',
        bytes: testBytes,
        isImage: true,
        onRemove: () => removed = true,
      ));

      await tester.pump();

      // Tap the X button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });
  });
}
