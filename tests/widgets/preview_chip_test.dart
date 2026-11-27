import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';

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

    testWidgets('tapping close button does NOT trigger onTap', (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(
        buildChip(
          isImage: true,
          bytes: validPng,
          onTap: () => tapped = true,
          onRemove: () => removed = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('fitting file names keep the original 72 dp chip height', (
      tester,
    ) async {
      await tester.pumpWidget(buildChip(fileName: 'notes.txt', isImage: false));

      expect(tester.getSize(find.byType(PreviewChip)).height, 72);
      expect(
        tester.widget<ConstrainedText>(find.byType(ConstrainedText)).data,
        'notes.txt',
      );
    });

    testWidgets('scaled filename height expands the chip surface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            textTheme: const TextTheme(bodyMedium: TextStyle(height: 1.2)),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: PreviewChip(
              fileName: 'quarterly-report.pdf',
              bytes: validPng,
              isImage: false,
              onRemove: () {},
            ),
          ),
        ),
      );

      final label = tester.widget<ConstrainedText>(
        find.byType(ConstrainedText),
      );
      expect(label.maxLines, 2);
      expect(label.data, 'quarterly-report.pdf');

      // At this scale, the label height plus its 16 dp inset exceeds the old
      // 72 dp fixed surface; the browser capture verifies its exact 2-line case.
      final labelSize = tester.getSize(find.byType(ConstrainedText));
      expect(labelSize.height, greaterThan(56));
      expect(labelSize.height + 16, greaterThan(72));
      expect(tester.getSize(find.byType(PreviewChip)).height, greaterThan(72));
      expect(tester.getSize(find.byType(PreviewChip)).width, 148);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long names reveal vertically and pause offscreen or reduced', (
      tester,
    ) async {
      const longName = 'quarterly-report-2024-final-archive-version.pdf';

      Widget fixture({bool disableAnimations = false, bool visible = true}) =>
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              textTheme: const TextTheme(bodyMedium: TextStyle(height: 1.2)),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                disableAnimations: disableAnimations,
              ),
              child: TickerMode(enabled: visible, child: child!),
            ),
            home: Scaffold(
              body: PreviewChip(
                fileName: longName,
                bytes: validPng,
                isImage: false,
                onRemove: () {},
              ),
            ),
          );

      await tester.pumpWidget(fixture());
      final constrainedText = find.byType(ConstrainedText);
      final label = tester.widget<ConstrainedText>(constrainedText);
      expect(label.data, longName);
      expect(label.maxLines, 2);
      final size = tester.getSize(find.byType(PreviewChip));
      expect(size.height, greaterThan(72));
      expect(size.height, lessThan(160));

      final text = find.text(longName);
      final start = tester.getTopLeft(text);
      final context = tester.element(constrainedText);
      final style = DefaultTextStyle.of(context).style.merge(label.style);
      final naturalText = TextPainter(
        text: TextSpan(text: longName, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: tester.getSize(constrainedText).width);
      final visibleText = TextPainter(
        text: TextSpan(text: longName, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: tester.getSize(constrainedText).width);
      final travel = Duration(
        milliseconds: ((naturalText.height - visibleText.height) / 24 * 1000)
            .round(),
      );
      expect(naturalText.height, greaterThan(visibleText.height));
      await tester.pump(const Duration(milliseconds: 999));
      expect(tester.getTopLeft(text).dy, closeTo(start.dy, 0.01));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(text).dy, lessThan(start.dy));

      final clip = find
          .ancestor(of: text, matching: find.byType(ClipRect))
          .first;
      final viewport = tester.getRect(clip);
      await tester.pump(travel);
      await tester.pump(const Duration(milliseconds: 20));
      final endpoint = tester.getRect(text);
      expect(endpoint.bottom, closeTo(viewport.bottom, 2));
      await tester.pump(const Duration(seconds: 1999));
      expect(tester.getTopLeft(text).dy, closeTo(endpoint.top, 0.01));
      await tester.pump(const Duration(milliseconds: 102));
      expect(tester.getTopLeft(text).dy, greaterThan(endpoint.top));

      await tester.pumpWidget(fixture(disableAnimations: true));
      final reducedMotionStart = tester.getTopLeft(find.text(longName));
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.getTopLeft(find.text(longName)).dy,
        closeTo(reducedMotionStart.dy, 0.01),
      );

      await tester.pumpWidget(fixture(visible: false));
      final offscreenStart = tester.getTopLeft(find.text(longName));
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.getTopLeft(find.text(longName)).dy,
        closeTo(offscreenStart.dy, 0.01),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
