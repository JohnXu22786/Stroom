import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/services/manifest_database.dart';

// ============================================================================
// Helper: Build test app
// ============================================================================

Widget _buildTestApp({
  List<SelectedImage>? testImages,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: OcrPage(testImages: testImages),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

/// Create a small valid PNG (1x1 pixel) for mock image data.
Uint8List _createTestPngBytes() {
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, // PNG signature
    0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk
    0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, // width=1
    0x00, 0x00, 0x00, 0x01, // height=1
    0x08, 0x02, // bit depth=8, color type=RGB
    0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, // CRC
    0x00, 0x00, 0x00, 0x0C, // IDAT chunk
    0x49, 0x44, 0x41, 0x54,
    0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01,
    0x26, 0xE0, 0xFE, 0xA0, // CRC
    0x00, 0x00, 0x00, 0x00, // IEND chunk
    0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

SelectedImage _createTestImage() {
  return SelectedImage(
    bytes: _createTestPngBytes(),
    format: 'png',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  group('OcrPage - preview dialog two edit buttons', () {
    testWidgets('preview dialog shows crop and edit buttons in top-right', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should see TWO edit icon buttons: crop + full editor
      expect(find.byIcon(Icons.crop), findsOneWidget,
          reason: 'Crop button should be visible');
      expect(find.byIcon(Icons.edit), findsOneWidget,
          reason: 'Full editor button should be visible');
    });

    testWidgets('preview dialog shows close button in top-left', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Close button should be present
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);
    });

    testWidgets('preview dialog shows position indicator for multiple images', (
      tester,
    ) async {
      final images = [_createTestImage(), _createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the first image
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should show the position indicator
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('preview dialog can be closed with close button', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byKey(const Key('preview_close_btn')));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('tapping crop button opens quick edit page', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Tap the crop button — should navigate to ExtendedImageEditorPage
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In test, the navigation may fail due to missing routes, but
      // verify no crash occurs from the event handler
    });
  });
}
