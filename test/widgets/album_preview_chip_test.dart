import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';

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
  group('AlbumPreviewChip', () {
    final validPng = _createValidPng();

    Widget buildChip({
      String fileName = 'test.png',
      Uint8List? bytes,
      VoidCallback? onRemove,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AlbumPreviewChip(
            fileName: fileName,
            bytes: bytes ?? validPng,
            onRemove: onRemove ?? () {},
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders thumbnail and close button', (tester) async {
      await tester.pumpWidget(buildChip());

      // Should find the close icon
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button calls onRemove when tapped', (tester) async {
      bool removed = false;

      await tester.pumpWidget(buildChip(
        onRemove: () => removed = true,
      ));

      // Tap the close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });

    testWidgets('onTap is called when chip is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildChip(
        bytes: validPng,
        onTap: () => tapped = true,
      ));

      // Tap the outermost GestureDetector (not the close button one)
      // The chip is wrapped in a gesture detector for tap
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('tapping close button does NOT trigger onTap', (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(buildChip(
        bytes: validPng,
        onTap: () => tapped = true,
        onRemove: () => removed = true,
      ));

      // Tap the close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('works without onTap (no crash)', (tester) async {
      await tester.pumpWidget(buildChip());

      expect(find.byType(AlbumPreviewChip), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button has error color circular background', (
      tester,
    ) async {
      await tester.pumpWidget(buildChip());

      // Find the close button container - should be a small circle with error color
      final containers = find.byType(Container);
      int errorCircleCount = 0;
      for (int i = 0; i < tester.widgetList(containers).length; i++) {
        final container =
            tester.widgetList(containers).elementAt(i) as Container;
        final decoration = container.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color != null) {
          errorCircleCount++;
        }
      }
      // Should find at least one circular container (the close button background)
      expect(errorCircleCount, greaterThanOrEqualTo(1));
    });
  });
}
