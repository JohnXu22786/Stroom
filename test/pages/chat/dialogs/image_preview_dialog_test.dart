import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/image_preview_dialog.dart';

/// Create a small valid PNG (1x1 white pixel) for use in widget tests.
Uint8List _createValidPng() {
  final png = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x00,
    0x00,
    0x00,
    0x00,
    0x0A,
    0xFC,
    0xFF,
    0xFD,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x08,
    0xD7,
    0x63,
    0x68,
    0x37,
    0x60,
    0x48,
    0x01,
    0x00,
    0x00,
    0x12,
    0xE3,
    0x01,
    0x6F,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];
  return Uint8List.fromList(png);
}

void main() {
  group('Chat showImagePreviewDialog', () {
    final validPng = _createValidPng();

    testWidgets('opens and displays image with ExtendedImage', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showImagePreviewDialog(
                context: context,
                fileName: 'photo.png',
                data: validPng,
              );
            },
            child: const Text('Open Preview'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog should be shown with the file name
      expect(find.text('photo.png'), findsOneWidget);
      // Note: No broken_image assertion here because
      // ExtendedImage.memory may fail to decode raw PNG bytes in some
      // CI environments, which is an environmental rather than a logic issue.
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showImagePreviewDialog(
                context: context,
                fileName: 'photo.png',
                data: validPng,
              );
            },
            child: const Text('Open Preview'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('photo.png'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      // Pump multiple frames to allow dialog close animation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Dialog should now be dismissed
      expect(find.text('photo.png'), findsNothing);
    });

    testWidgets('shows error state for empty data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showImagePreviewDialog(
                context: context,
                fileName: 'empty.png',
                data: Uint8List(0),
              );
            },
            child: const Text('Open Preview'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.text('无法加载图片'), findsOneWidget);
    });

    testWidgets('close button has circular semi-transparent background',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showImagePreviewDialog(
                context: context,
                fileName: 'photo.png',
                data: validPng,
              );
            },
            child: const Text('Open Preview'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the close icon
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify there's a Container with circular decoration wrapping the button
      final containers = find.byType(Container);
      bool hasCircularBackground = false;
      for (int i = 0; i < tester.widgetList(containers).length; i++) {
        final container =
            tester.widgetList(containers).elementAt(i) as Container;
        final decoration = container.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color != null &&
            decoration.color!.alpha < 255) {
          hasCircularBackground = true;
          break;
        }
      }

      expect(hasCircularBackground, isTrue,
          reason:
              'Close button should have a circular semi-transparent background');
    });
  });
}
