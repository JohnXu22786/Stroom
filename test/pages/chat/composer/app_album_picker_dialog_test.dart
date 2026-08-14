import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses, alternating
/// real-async windows (engine image work) with pumps (fake-zone
/// continuations).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition');
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
  });

  // ====================================================================
  // Quick-edit flow: the editor processes the image in place (the page
  // stays open while processing) and the selection is updated with the
  // edited bytes once it pops.
  // ====================================================================
  group('AppAlbumPickerDialog quick-edit flow', () {
    testWidgets(
        'the quick editor processes in place, then the selection holds '
        'the edited bytes', (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      // Seed the test-mode image library with one real image.
      await tester.runAsync(() async {
        await ImageManifest.writeFile('gate-hash.png', png!);
        await ImageManifest.addRecord(
          ImageRecord(
            name: 'gate-image',
            hash: 'gate-hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: png.length,
            folder: '',
          ),
        );
      });

      List<MapEntry<String, Uint8List>>? pickerResult;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickerResult = await showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // The record list loads via real manifest IO in the fake zone —
      // wait for the image tile to appear.
      await _pumpUntil(
        tester,
        () => find.text('gate-image.png').evaluate().isNotEmpty,
      );

      // Select the image — the file is read asynchronously (real IO).
      await tester.tap(find.text('gate-image.png'));
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find.byType(AlbumPreviewChip).evaluate().isNotEmpty,
      );
      final originalChipBytes =
          tester.widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip)).bytes;

      // Preview chip → preview dialog → quick editor.
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for the editor image to decode (engine work — real async).
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Confirm the edit — the editor must NOT close immediately: it
      // processes the image in place with a spinner until the pipeline
      // finishes.
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
          reason: 'the editor must stay on screen while processing');
      expect(
        find.descendant(
          of: find.byType(ExtendedImageEditorPage),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a processing spinner must be visible',
      );

      // Only after the pipeline finishes does the editor pop back to the
      // picker.
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
      );

      // The selection now holds the edited bytes — the preview chip
      // shows a NEW bytes instance.
      await _pumpUntil(
        tester,
        () =>
            tester
                .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
                .bytes !=
            originalChipBytes,
      );

      // Confirming returns the edited bytes.
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pump();
      expect(pickerResult, isNotNull);
      expect(pickerResult!.single.value, isNot(same(originalChipBytes)),
          reason: 'the confirmed selection must hold the edited bytes');
    });
  });
}
