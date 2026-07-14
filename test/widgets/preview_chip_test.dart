import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';

/// Create a small valid PNG (1x1 white pixel) for use in widget tests.
Uint8List _createValidPng() {
  // Minimal PNG (1x1 pixel, 8-bit grayscale)
  final png = <int>[
    0x89, 0x50, 0x4E, 0x47, // PNG signature
    0x0D, 0x0A, 0x1A, 0x0A, // CR+LF+CtrlZ+LF
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk length = 13
    0x49, 0x48, 0x44, 0x52, // "IHDR" type
    0x00, 0x00, 0x00, 0x01, // width = 1
    0x00, 0x00, 0x00, 0x01, // height = 1
    0x08, 0x00, // bit depth = 8, color type = Grayscale
    0x00, 0x00, 0x00, // compression, filter, interlace (defaults)
    0x0A, 0xFC, 0xFF, 0xFD, // IHDR CRC
    0x00, 0x00, 0x00, 0x0A, // IDAT chunk length = 10
    0x49, 0x44, 0x41, 0x54, // "IDAT" type
    0x08, 0xD7, 0x63, 0x68,
    0x37, 0x60, 0x48, 0x01,
    0x00, 0x00, 0x12, 0xE3,
    0x01, 0x6F, // IDAT data + CRC
    0x00, 0x00, 0x00, 0x00, // IEND chunk length = 0
    0x49, 0x45, 0x4E, 0x44, // "IEND"
    0xAE, 0x42, 0x60, 0x82, // IEND CRC
  ];
  return Uint8List.fromList(png);
}

void main() {
  group('PreviewChip (file_picker_shared)', () {
    final validPng = _createValidPng();

    Widget buildChip({
      String fileName = 'test.png',
      Uint8List? bytes,
      bool isImage = true,
      VoidCallback? onRemove,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PreviewChip(
            fileName: fileName,
            bytes: bytes ?? validPng,
            isImage: isImage,
            onRemove: onRemove ?? () {},
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders image thumbnail when isImage=true', (tester) async {
      await tester.pumpWidget(buildChip(isImage: true, bytes: validPng));

      // Should render the chip widget
      expect(find.byType(PreviewChip), findsOneWidget);
      // Close icon should be present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders file icon when isImage=false', (tester) async {
      await tester.pumpWidget(buildChip(
        fileName: 'document.pdf',
        isImage: false,
        bytes: Uint8List.fromList([0, 1, 2, 3]),
      ));

      // Should render the chip
      expect(find.byType(PreviewChip), findsOneWidget);
      // Should show file icon
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      // Close icon should be present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button calls onRemove when tapped', (tester) async {
      bool removed = false;

      await tester.pumpWidget(buildChip(
        isImage: true,
        bytes: validPng,
        onRemove: () => removed = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });

    testWidgets('onTap is called when chip is tapped (image)', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildChip(
        isImage: true,
        bytes: validPng,
        onTap: () => tapped = true,
      ));

      // Tap the PreviewChip widget area
      await tester.tap(find.byType(PreviewChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('tapping close button does NOT trigger onTap', (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(buildChip(
        isImage: true,
        bytes: validPng,
        onTap: () => tapped = true,
        onRemove: () => removed = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('works without onTap (no crash)', (tester) async {
      await tester.pumpWidget(buildChip(isImage: true, bytes: validPng));

      expect(find.byType(PreviewChip), findsOneWidget);
    });
  });
}
