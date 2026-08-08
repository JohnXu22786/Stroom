import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';

/// Create a small valid PNG (1x1 white pixel) for use in widget tests.
/// ExtendedImage and Image.memory need structurally valid image bytes.
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
  group('ImagePreviewDialog', () {
    final validPng = _createValidPng();

    Widget buildDialog({
      Uint8List? imageData,
      String fileName = 'test.jpg',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ImagePreviewDialog(
            imageData: imageData,
            fileName: fileName,
          ),
        ),
      );
    }

    /// Pump the dialog and wait for frames.
    Future<void> pumpDialog(
      WidgetTester tester, {
      Uint8List? imageData,
      String fileName = 'test.jpg',
    }) async {
      await tester.pumpWidget(buildDialog(
        imageData: imageData,
        fileName: fileName,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    // ================================================================
    // Basic rendering
    // ================================================================

    testWidgets('shows error state when imageData is null', (tester) async {
      await pumpDialog(tester, imageData: null);

      expect(find.byIcon(Icons.broken_image), findsOneWidget,
          reason: 'broken_image icon when imageData is null');
      expect(find.text('无法加载图片'), findsOneWidget,
          reason: 'Error text when imageData is null');
    });

    testWidgets('shows error state when imageData is empty', (tester) async {
      await pumpDialog(tester, imageData: Uint8List(0));

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.text('无法加载图片'), findsOneWidget);
    });

    // ================================================================
    // Interaction: buttons
    // ================================================================

    testWidgets('close button pops dialog with false', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => ImagePreviewDialog(
                  imageData: validPng,
                  fileName: 'test.jpg',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(result, false);
    });

    testWidgets('crop button pops dialog with true', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => ImagePreviewDialog(
                  imageData: validPng,
                  fileName: 'test.jpg',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();

      expect(result, true);
    });

    testWidgets('edit button pops dialog with true', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => ImagePreviewDialog(
                  imageData: validPng,
                  fileName: 'test.jpg',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      expect(result, true);
    });

    testWidgets('crop and edit buttons are always enabled', (tester) async {
      bool? result;
      bool? dialogClosed;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => ImagePreviewDialog(
                  imageData: validPng,
                  fileName: 'test.jpg',
                ),
              );
              dialogClosed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      // Crop button should be enabled immediately
      final cropIcon = find.byIcon(Icons.crop);
      final cropButton = tester.widget<IconButton>(
        find.ancestor(of: cropIcon, matching: find.byType(IconButton)),
      );
      expect(cropButton.onPressed, isNotNull,
          reason: 'Crop button should be enabled');

      // Tapping crop button immediately pops dialog with true
      await tester.tap(cropIcon);
      await tester.pump();
      expect(dialogClosed, isTrue,
          reason: 'Dialog should close immediately after tapping crop button');
      expect(result, isTrue, reason: 'Crop button should pop with true');
    });

    // ================================================================
    // SVG files: crop and edit buttons hidden
    // ================================================================

    testWidgets('SVG files hide crop and edit buttons', (tester) async {
      await pumpDialog(tester, imageData: validPng, fileName: 'image.svg');

      // Close button should still be present
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Crop and edit buttons should NOT be present for SVG
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    // ================================================================
    // Dialog lifecycle safety
    // ================================================================

    testWidgets('rapid open/close does not crash', (tester) async {
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showDialog<bool>(
                  context: context,
                  builder: (_) => ImagePreviewDialog(
                    imageData: validPng,
                    fileName: 'test.jpg',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ));

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
      }
      // Test passes if no crash
    });
  });
}
